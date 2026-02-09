//
//  LinkRepository.swift
//  CalSync
//
//  Created by Codex on 09.02.2026.
//

import CoreData
import Foundation

struct SourceFallbackKey {
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
