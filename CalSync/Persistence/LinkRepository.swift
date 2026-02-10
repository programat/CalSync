//
//  LinkRepository.swift
//  CalSync
//
//  Created by Codex on 09.02.2026.
//

import CoreData
import Foundation

nonisolated struct SourceEventKey {
    let primary: String?
    let fallback: SourceFallbackKey?

    init(sourceEvent: EventInfo) {
        if let calendarItemId = sourceEvent.calendarItemId {
            fallback = SourceFallbackKey(
                sourceCalendarItemId: calendarItemId,
                sourceDate: sourceEvent.occurrenceDate ?? sourceEvent.startDate
            )
        } else {
            fallback = nil
        }

        // Treat any event with occurrenceDate as a recurring instance even if
        // EventKit does not expose recurrence rules on that instance.
        if sourceEvent.isRecurring || sourceEvent.occurrenceDate != nil {
            primary = nil
        } else {
            primary = sourceEvent.eventId
        }
    }
}

nonisolated struct SourceFallbackKey: Hashable, Sendable {
    let sourceCalendarItemId: String
    let sourceDate: Date
}

struct SyncedEventLinkPayload {
    var id: UUID
    var sourceCalendarId: String
    var childCalendarId: String
    var sourceEventId: String?
    var sourceCalendarItemId: String?
    var sourceOccurrenceDate: Date?
    var sourceStartLastSeen: Date
    var sourceEndLastSeen: Date
    var childEventId: String
    var lastSyncedAt: Date
    var lastSeenInSourceAt: Date
    var lastSyncHash: String
}

final class LinkRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    @discardableResult
    func create(_ payload: SyncedEventLinkPayload) throws -> SyncedEventLink {
        try context.performAndWait {
            let link = SyncedEventLink(context: context)
            apply(payload, to: link)
            try saveIfNeeded()
            return link
        }
    }

    func fetch(id: UUID) throws -> SyncedEventLink? {
        try context.performAndWait {
            let request = SyncedEventLink.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            return try context.fetch(request).first
        }
    }

    func fetchAll() throws -> [SyncedEventLink] {
        try context.performAndWait {
            let request = SyncedEventLink.fetchRequest()
            return try context.fetch(request)
        }
    }

    func deleteAll() throws {
        try context.performAndWait {
            let request = SyncedEventLink.fetchRequest()
            let links = try context.fetch(request)
            links.forEach(context.delete)
            try saveIfNeeded()
        }
    }

    @discardableResult
    func update(id: UUID, payload: SyncedEventLinkPayload) throws -> SyncedEventLink? {
        try context.performAndWait {
            guard let link = try fetchInternal(id: id) else {
                return nil
            }
            apply(payload, to: link)
            try saveIfNeeded()
            return link
        }
    }

    func delete(id: UUID) throws {
        try context.performAndWait {
            guard let link = try fetchInternal(id: id) else {
                return
            }
            context.delete(link)
            try saveIfNeeded()
        }
    }

    func findBySourceEventId(_ sourceEventId: String) throws -> SyncedEventLink? {
        try context.performAndWait {
            let request = SyncedEventLink.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "sourceEventId == %@", sourceEventId)
            return try context.fetch(request).first
        }
    }

    func findByFallbackKey(_ key: SourceFallbackKey) throws -> SyncedEventLink? {
        try context.performAndWait {
            let request = SyncedEventLink.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(
                format: """
                sourceCalendarItemId == %@ AND \
                ((sourceOccurrenceDate == %@) OR (sourceOccurrenceDate == NIL AND sourceStartLastSeen == %@))
                """,
                key.sourceCalendarItemId,
                key.sourceDate as CVarArg,
                key.sourceDate as CVarArg
            )
            return try context.fetch(request).first
        }
    }

    func findLink(for sourceEvent: EventInfo) throws -> SyncedEventLink? {
        let key = SourceEventKey(sourceEvent: sourceEvent)

        if let primary = key.primary,
           !primary.isEmpty,
           let link = try findBySourceEventId(primary) {
            return link
        }

        if let fallback = key.fallback {
            return try findByFallbackKey(fallback)
        }

        return nil
    }

    func updateSourceEventIdIfNeeded(_ link: SyncedEventLink, newId: String?) throws {
        try context.performAndWait {
            guard
                let linkId = link.id,
                let newId,
                !newId.isEmpty,
                let persistedLink = try fetchInternal(id: linkId),
                persistedLink.sourceEventId != newId
            else {
                return
            }

            persistedLink.sourceEventId = newId
            try saveIfNeeded()
        }
    }

    func updateLastSeenInSourceAt(_ link: SyncedEventLink, at timestamp: Date) throws {
        try context.performAndWait {
            guard
                let linkId = link.id,
                let persistedLink = try fetchInternal(id: linkId)
            else {
                return
            }

            persistedLink.lastSeenInSourceAt = timestamp
            try saveIfNeeded()
        }
    }

    private func fetchInternal(id: UUID) throws -> SyncedEventLink? {
        let request = SyncedEventLink.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try context.fetch(request).first
    }

    private func apply(_ payload: SyncedEventLinkPayload, to link: SyncedEventLink) {
        link.id = payload.id
        link.sourceCalendarId = payload.sourceCalendarId
        link.childCalendarId = payload.childCalendarId
        link.sourceEventId = payload.sourceEventId
        link.sourceCalendarItemId = payload.sourceCalendarItemId
        link.sourceOccurrenceDate = payload.sourceOccurrenceDate
        link.sourceStartLastSeen = payload.sourceStartLastSeen
        link.sourceEndLastSeen = payload.sourceEndLastSeen
        link.childEventId = payload.childEventId
        link.lastSyncedAt = payload.lastSyncedAt
        link.lastSeenInSourceAt = payload.lastSeenInSourceAt
        link.lastSyncHash = payload.lastSyncHash
    }

    private func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
