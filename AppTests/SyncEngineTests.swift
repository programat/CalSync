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
        let (engine, _, userDefaults, suiteName) = makeSyncEngine(
            debounce: .milliseconds(100),
            syncWorkOverride: { _ in
                await probe.beginRun()
                await probe.finishRun()
                return 0
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
        let (engine, _, userDefaults, suiteName) = makeSyncEngine(
            debounce: .milliseconds(100),
            syncWorkOverride: { _ in
                await probe.beginRun()
                try? await Task.sleep(nanoseconds: 200_000_000)
                await probe.finishRun()
                return 0
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
        let (engine, gateway, userDefaults, suiteName) = makeSyncEngine(
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

    func record(_ update: SyncEngineUpdate) {
        updates.append(update)
    }
}

private func makeSyncEngine(
    debounce: Duration = .seconds(2),
    onUpdate: SyncEngine.UpdateHandler? = nil,
    syncWorkOverride: SyncEngine.SyncWork? = nil
) -> (SyncEngine, FakeEventKitGateway, UserDefaults, String) {
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

    return (engine, gateway, userDefaults, suiteName)
}

private func sleep(milliseconds: UInt64) async throws {
    try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
}
