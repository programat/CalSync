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
}
