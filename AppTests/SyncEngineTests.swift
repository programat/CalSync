//
//  SyncEngineTests.swift
//  AppTests
//
//  Created by Codex on 09.02.2026.
//

import Foundation
import CoreData
import Testing
@testable import CalSync

struct SyncEngineTests {

    @Test func requestSyncDebouncesRapidBurstIntoSingleRun() async throws {
        let probe = SyncRunProbe()
        let (engine, _, _, _, _, userDefaults, suiteName) = makeSyncEngine(
            debounce: .milliseconds(100),
            syncWorkOverride: { _ in
                await probe.beginRun()
                await probe.finishRun()
                return SyncEngine.SyncResult(totalFetched: 0, created: 0, updated: 0)
            }
        )
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        for _ in 0..<10 {
            await engine.requestSync(reason: .eventStoreChanged)
        }

        try await sleep(milliseconds: 300)

        #expect(await probe.runs == 1)
        #expect(await probe.maxConcurrentRuns == 1)
    }

    @Test func syncNowKeepsSingleFlightWhenCalledInParallel() async throws {
        let probe = SyncRunProbe()
        let (engine, _, _, _, _, userDefaults, suiteName) = makeSyncEngine(
            debounce: .milliseconds(100),
            syncWorkOverride: { _ in
                await probe.beginRun()
                try? await Task.sleep(nanoseconds: 200_000_000)
                await probe.finishRun()
                return SyncEngine.SyncResult(totalFetched: 0, created: 0, updated: 0)
            }
        )
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let first = Task { await engine.syncNow() }
        try await sleep(milliseconds: 50)
        let second = Task { await engine.syncNow() }

        _ = await first.value
        _ = await second.value

        #expect(await probe.maxConcurrentRuns == 1)
        #expect(await probe.runs == 2)
    }

    @Test func computeWindowUsesStartAndEndOfDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let now = Date(timeIntervalSince1970: 1_706_959_800) // 2024-02-03 11:30:00 UTC
        let window = SyncEngine.computeWindow(
            now: now,
            daysBack: 2,
            daysForward: 3,
            calendar: calendar
        )

        let expectedFrom = Date(timeIntervalSince1970: 1_706_745_600) // 2024-02-01 00:00:00 UTC
        let expectedTo = Date(timeIntervalSince1970: 1_707_263_999)   // 2024-02-06 23:59:59 UTC

        #expect(window.from == expectedFrom)
        #expect(window.to == expectedTo)
    }

    @Test func syncNowFailsWhenCalendarsAreNotSelected() async throws {
        let updateProbe = SyncUpdateProbe()
        let (engine, gateway, _, _, _, userDefaults, suiteName) = makeSyncEngine(
            onUpdate: { update in
                await updateProbe.record(update)
            }
        )
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        await engine.syncNow()

        let updates = await updateProbe.updates
        #expect(updates.contains(.syncing))
        #expect(updates.contains(.failed(message: "Source и Child календари должны быть выбраны.")))
        #expect(gateway.fetchEventsCallCount == 0)
    }

    @Test func createNewMirrorWhenLinkMissing() async throws {
        let updateProbe = SyncUpdateProbe()
        let (engine, gateway, linkRepo, _, settings, userDefaults, suiteName) = makeSyncEngine(
            onUpdate: { update in
                await updateProbe.record(update)
            }
        )
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        settings.sourceCalendarId = "source-calendar"
        settings.childCalendarId = "child-calendar"
        gateway.fetchEventsToReturn = [
            makeSourceEvent(eventId: "source-1", calendarItemId: "item-1", startAt: 1_737_000_000)
        ]

        await engine.syncNow()

        #expect(gateway.createEventCallCount == 1)
        #expect(gateway.updateEventCallCount == 0)
        let createCallSnapshot = await MainActor.run {
            let firstCall = gateway.createEventCalls.first
            return (
                calendarId: firstCall?.calendarId,
                eventId: firstCall?.payload.eventId,
                calendarItemId: firstCall?.payload.calendarItemId,
                occurrenceDate: firstCall?.payload.occurrenceDate
            )
        }
        #expect(createCallSnapshot.calendarId == "child-calendar")
        #expect(createCallSnapshot.eventId == nil)
        #expect(createCallSnapshot.calendarItemId == nil)
        #expect(createCallSnapshot.occurrenceDate == nil)

        let links = try await MainActor.run { try linkRepo.fetchAll() }
        #expect(links.count == 1)
        #expect(links.first?.childEventId == "child-event-1")

        let completionStats = await updateProbe.completionStats
        let hasExpectedCompletion = completionStats.contains { stats in
            stats.totalFetched == 1 && stats.created == 1 && stats.updated == 0
        }
        #expect(hasExpectedCompletion)
    }

    @Test func updateExistingMirrorWhenHashChanged() async throws {
        let (engine, gateway, linkRepo, _, settings, userDefaults, suiteName) = makeSyncEngine()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        settings.sourceCalendarId = "source-calendar"
        settings.childCalendarId = "child-calendar"

        let sourceEvent = makeSourceEvent(eventId: "source-1", calendarItemId: "item-1", startAt: 1_737_000_000)
        gateway.fetchEventsToReturn = [sourceEvent]
        gateway.eventsById["child-existing"] = makeSourceEvent(
            eventId: "child-existing",
            calendarItemId: nil,
            startAt: 1_737_000_000
        )

        try await MainActor.run {
            _ = try linkRepo.create(
                SyncedEventLinkPayload(
                    id: UUID(),
                    sourceCalendarId: "source-calendar",
                    childCalendarId: "child-calendar",
                    sourceEventId: "source-1",
                    sourceCalendarItemId: "item-1",
                    sourceOccurrenceDate: nil,
                    sourceStartLastSeen: sourceEvent.startDate,
                    sourceEndLastSeen: sourceEvent.endDate,
                    childEventId: "child-existing",
                    lastSyncedAt: sourceEvent.startDate,
                    lastSeenInSourceAt: sourceEvent.startDate,
                    lastSyncHash: "stale-hash"
                )
            )
        }

        await engine.syncNow()

        #expect(gateway.createEventCallCount == 0)
        #expect(gateway.updateEventCallCount == 1)
        let firstUpdatedEventId = await MainActor.run {
            gateway.updateEventCalls.first?.eventId
        }
        #expect(firstUpdatedEventId == "child-existing")

        let expectedHash = SyncEngine.hashKeyFields(for: SyncEngine.makeMirrorPayload(from: sourceEvent))
        let links = try await MainActor.run { try linkRepo.fetchAll() }
        #expect(links.first?.lastSyncHash == expectedHash)
    }

    @Test func recreateMirrorWhenChildWasDeletedManually() async throws {
        let (engine, gateway, linkRepo, _, settings, userDefaults, suiteName) = makeSyncEngine()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        settings.sourceCalendarId = "source-calendar"
        settings.childCalendarId = "child-calendar"

        let sourceEvent = makeSourceEvent(eventId: "source-1", calendarItemId: "item-1", startAt: 1_737_000_000)
        gateway.fetchEventsToReturn = [sourceEvent]

        try await MainActor.run {
            _ = try linkRepo.create(
                SyncedEventLinkPayload(
                    id: UUID(),
                    sourceCalendarId: "source-calendar",
                    childCalendarId: "child-calendar",
                    sourceEventId: "source-1",
                    sourceCalendarItemId: "item-1",
                    sourceOccurrenceDate: nil,
                    sourceStartLastSeen: sourceEvent.startDate,
                    sourceEndLastSeen: sourceEvent.endDate,
                    childEventId: "child-missing",
                    lastSyncedAt: sourceEvent.startDate,
                    lastSeenInSourceAt: sourceEvent.startDate,
                    lastSyncHash: SyncEngine.hashKeyFields(for: SyncEngine.makeMirrorPayload(from: sourceEvent))
                )
            )
        }

        await engine.syncNow()

        #expect(gateway.getEventCallCount == 1)
        #expect(gateway.createEventCallCount == 1)
        #expect(gateway.updateEventCallCount == 0)

        let links = try await MainActor.run { try linkRepo.fetchAll() }
        #expect(links.first?.childEventId == "child-event-1")
    }
}

private actor SyncRunProbe {
    private(set) var runs = 0
    private(set) var currentConcurrentRuns = 0
    private(set) var maxConcurrentRuns = 0

    func beginRun() {
        runs += 1
        currentConcurrentRuns += 1
        maxConcurrentRuns = max(maxConcurrentRuns, currentConcurrentRuns)
    }

    func finishRun() {
        currentConcurrentRuns = max(0, currentConcurrentRuns - 1)
    }
}

private actor SyncUpdateProbe {
    private(set) var updates: [SyncEngineUpdate] = []

    struct CompletionStats {
        let totalFetched: Int
        let created: Int
        let updated: Int
    }

    func record(_ update: SyncEngineUpdate) {
        updates.append(update)
    }

    var completionStats: [CompletionStats] {
        updates.compactMap { update in
            if case let .completed(_, totalFetched, created, updated) = update {
                return CompletionStats(totalFetched: totalFetched, created: created, updated: updated)
            }
            return nil
        }
    }
}

private func makeSyncEngine(
    debounce: Duration = .seconds(2),
    onUpdate: SyncEngine.UpdateHandler? = nil,
    syncWorkOverride: SyncEngine.SyncWork? = nil
) -> (SyncEngine, FakeEventKitGateway, LinkRepository, ErrorRepository, UserDefaultsSettingsStore, UserDefaults, String) {
    let persistence = PersistenceController(inMemory: true)
    let context = persistence.container.viewContext
    let linkRepo = LinkRepository(context: context)
    let errorRepo = ErrorRepository(context: context)
    let gateway = FakeEventKitGateway()

    let suiteName = "CalSyncTests.SyncEngine.\(UUID().uuidString)"
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
        fatalError("Failed to create UserDefaults suite \(suiteName)")
    }
    userDefaults.removePersistentDomain(forName: suiteName)
    let settings = UserDefaultsSettingsStore(userDefaults: userDefaults)

    let engine = SyncEngine(
        gateway: gateway,
        linkRepo: linkRepo,
        errorRepo: errorRepo,
        settings: settings,
        debounceDuration: debounce,
        onUpdate: onUpdate,
        syncWorkOverride: syncWorkOverride
    )

    return (engine, gateway, linkRepo, errorRepo, settings, userDefaults, suiteName)
}

private func sleep(milliseconds: UInt64) async throws {
    try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
}

private func makeSourceEvent(
    eventId: String?,
    calendarItemId: String?,
    startAt timestamp: TimeInterval
) -> EventInfo {
    let startDate = Date(timeIntervalSince1970: timestamp)
    return EventInfo(
        eventId: eventId,
        calendarItemId: calendarItemId,
        occurrenceDate: nil,
        title: "Title \(eventId ?? "none")",
        notes: "Notes",
        location: "Location",
        structuredLocation: nil,
        startDate: startDate,
        endDate: startDate.addingTimeInterval(3600),
        isAllDay: false,
        timeZone: TimeZone(secondsFromGMT: 0),
        availability: .busy,
        status: .confirmed,
        alarms: [],
        url: URL(string: "https://example.com/\(eventId ?? "none")")
    )
}
