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
        let (engine, userDefaults, suiteName) = makeSyncEngine(
            debounce: .milliseconds(100),
            performSyncWork: { _ in
                await probe.beginRun()
                await probe.finishRun()
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
        let (engine, userDefaults, suiteName) = makeSyncEngine(
            debounce: .milliseconds(100),
            performSyncWork: { _ in
                await probe.beginRun()
                try? await Task.sleep(nanoseconds: 200_000_000)
                await probe.finishRun()
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

private func makeSyncEngine(
    debounce: Duration = .seconds(2),
    performSyncWork: @escaping SyncEngine.SyncWork
) -> (SyncEngine, UserDefaults, String) {
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
        performSyncWork: performSyncWork
    )

    return (engine, userDefaults, suiteName)
}

private func sleep(milliseconds: UInt64) async throws {
    try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
}
