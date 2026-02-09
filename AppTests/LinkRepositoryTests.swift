//
//  LinkRepositoryTests.swift
//  AppTests
//
//  Created by Codex on 09.02.2026.
//

import Foundation
import CoreData
import Testing
@testable import CalSync

struct LinkRepositoryTests {

    @Test func createFindByIdAndDeleteLink() throws {
        let persistence = PersistenceController(inMemory: true)
        let repository = LinkRepository(context: persistence.container.viewContext)

        let id = UUID()
        let referenceDate = Date(timeIntervalSince1970: 1_737_000_000)
        let payload = SyncedEventLinkPayload(
            id: id,
            sourceCalendarId: "source-calendar",
            childCalendarId: "child-calendar",
            sourceEventId: "source-event-id",
            sourceCalendarItemId: "source-calendar-item-id",
            sourceOccurrenceDate: referenceDate,
            sourceStartLastSeen: referenceDate,
            sourceEndLastSeen: referenceDate.addingTimeInterval(3_600),
            childEventId: "child-event-id",
            lastSyncedAt: referenceDate,
            lastSeenInSourceAt: referenceDate,
            lastSyncHash: "hash"
        )

        let created = try repository.create(payload)
        #expect(created.id == id)

        let fetched = try repository.fetch(id: id)
        #expect(fetched != nil)
        #expect(fetched?.childEventId == "child-event-id")

        try repository.delete(id: id)

        let deleted = try repository.fetch(id: id)
        #expect(deleted == nil)
    }

    @Test func findLinkMatchesBySourceEventId() throws {
        let persistence = PersistenceController(inMemory: true)
        let repository = LinkRepository(context: persistence.container.viewContext)

        let referenceDate = Date(timeIntervalSince1970: 1_737_000_000)
        let payload = SyncedEventLinkPayload(
            id: UUID(),
            sourceCalendarId: "source-calendar",
            childCalendarId: "child-calendar",
            sourceEventId: "source-event-id",
            sourceCalendarItemId: "source-calendar-item-id",
            sourceOccurrenceDate: referenceDate,
            sourceStartLastSeen: referenceDate,
            sourceEndLastSeen: referenceDate.addingTimeInterval(3_600),
            childEventId: "child-event-id",
            lastSyncedAt: referenceDate,
            lastSeenInSourceAt: referenceDate,
            lastSyncHash: "hash"
        )
        let created = try repository.create(payload)

        let event = makeEventInfo(
            eventId: "source-event-id",
            calendarItemId: "other-calendar-item-id",
            occurrenceDate: nil,
            startDate: referenceDate.addingTimeInterval(86_400)
        )

        let matched = try repository.findLink(for: event)
        #expect(matched?.id == created.id)
    }

    @Test func findLinkMatchesByFallbackWhenPrimaryNotFound() throws {
        let persistence = PersistenceController(inMemory: true)
        let repository = LinkRepository(context: persistence.container.viewContext)

        let referenceDate = Date(timeIntervalSince1970: 1_737_000_000)
        let payload = SyncedEventLinkPayload(
            id: UUID(),
            sourceCalendarId: "source-calendar",
            childCalendarId: "child-calendar",
            sourceEventId: nil,
            sourceCalendarItemId: "source-calendar-item-id",
            sourceOccurrenceDate: nil,
            sourceStartLastSeen: referenceDate,
            sourceEndLastSeen: referenceDate.addingTimeInterval(3_600),
            childEventId: "child-event-id",
            lastSyncedAt: referenceDate,
            lastSeenInSourceAt: referenceDate,
            lastSyncHash: "hash"
        )
        let created = try repository.create(payload)

        let event = makeEventInfo(
            eventId: "new-source-event-id",
            calendarItemId: "source-calendar-item-id",
            occurrenceDate: nil,
            startDate: referenceDate
        )

        let matched = try repository.findLink(for: event)
        #expect(matched?.id == created.id)
    }
}

private func makeEventInfo(
    eventId: String?,
    calendarItemId: String?,
    occurrenceDate: Date?,
    startDate: Date
) -> EventInfo {
    EventInfo(
        eventId: eventId,
        calendarItemId: calendarItemId,
        occurrenceDate: occurrenceDate,
        title: "Title",
        notes: "Notes",
        location: "Location",
        structuredLocation: nil,
        startDate: startDate,
        endDate: startDate.addingTimeInterval(3_600),
        isAllDay: false,
        timeZone: TimeZone(secondsFromGMT: 0),
        availability: .busy,
        status: .confirmed,
        alarms: [],
        url: nil
    )
}
