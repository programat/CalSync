//
//  SyncEngine.swift
//  CalSync
//
//  Created by Codex on 09.02.2026.
//

import Foundation
import os

nonisolated enum SyncReason: Hashable, Sendable {
    case manual
    case eventStoreChanged
    case fallbackTimer
}

nonisolated protocol SyncEngineClock: Sendable {
    func sleep(for duration: Duration) async throws
}

nonisolated struct ContinuousSyncEngineClock: SyncEngineClock {
    private let clock = ContinuousClock()

    func sleep(for duration: Duration) async throws {
        try await clock.sleep(for: duration)
    }
}

actor SyncEngine {
    typealias DateProvider = @Sendable () -> Date
    typealias LastSyncCallback = @MainActor @Sendable (Date) -> Void
    typealias SyncWork = @Sendable (Set<SyncReason>) async -> Void

    private let gateway: EventKitGateway
    private let linkRepo: LinkRepository
    private let errorRepo: ErrorRepository
    private let settings: SettingsStore
    private let dateProvider: DateProvider
    private let clock: any SyncEngineClock
    private let debounceDuration: Duration
    private let fallbackInterval: Duration
    private let onLastSyncAtUpdated: LastSyncCallback?
    private let performSyncWork: SyncWork
    private let logger = Logger(subsystem: "CalSync", category: "SyncEngine")

    private var eventStoreObserver: AnyObject?
    private var debounceTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?
    private var pendingReasons: Set<SyncReason> = []
    private var isSyncing = false
    private var needResync = false

    init(
        gateway: EventKitGateway,
        linkRepo: LinkRepository,
        errorRepo: ErrorRepository,
        settings: SettingsStore,
        dateProvider: @escaping DateProvider = Date.init,
        clock: any SyncEngineClock = ContinuousSyncEngineClock(),
        debounceDuration: Duration = .seconds(2),
        fallbackInterval: Duration = .seconds(15 * 60),
        onLastSyncAtUpdated: LastSyncCallback? = nil,
        performSyncWork: SyncWork? = nil
    ) {
        self.gateway = gateway
        self.linkRepo = linkRepo
        self.errorRepo = errorRepo
        self.settings = settings
        self.dateProvider = dateProvider
        self.clock = clock
        self.debounceDuration = debounceDuration
        self.fallbackInterval = fallbackInterval
        self.onLastSyncAtUpdated = onLastSyncAtUpdated
        self.performSyncWork = performSyncWork ?? { _ in }
    }

    deinit {
        debounceTask?.cancel()
        fallbackTask?.cancel()
    }

    func requestSync(reason: SyncReason) {
        pendingReasons.insert(reason)

        debounceTask?.cancel()
        debounceTask = Task { [clock, debounceDuration] in
            do {
                try await clock.sleep(for: debounceDuration)
                await self.flushDebouncedSyncRequest()
            } catch {
                return
            }
        }
    }

    func syncNow() async {
        pendingReasons.insert(.manual)
        debounceTask?.cancel()
        debounceTask = nil
        await startSyncIfPossible()
    }

    func resetSync() async {
        do {
            try await MainActor.run {
                try linkRepo.deleteAll()
                try errorRepo.deleteAll()
            }
            logger.info("Reset sync: cleared links and errors.")
        } catch {
            logger.error("Reset sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func startObservingEventStoreChanges() {
        guard eventStoreObserver == nil else { return }

        eventStoreObserver = gateway.observeStoreChanges { [weak self] in
            guard let self else { return }
            Task {
                await self.requestSync(reason: .eventStoreChanged)
            }
        }
    }

    func startFallbackTimer() {
        fallbackTask?.cancel()
        fallbackTask = Task { [clock, fallbackInterval] in
            while !Task.isCancelled {
                do {
                    try await clock.sleep(for: fallbackInterval)
                } catch {
                    return
                }
                self.requestSync(reason: .fallbackTimer)
            }
        }
    }

    private func flushDebouncedSyncRequest() async {
        debounceTask = nil
        await startSyncIfPossible()
    }

    private func startSyncIfPossible() async {
        guard !isSyncing else {
            needResync = true
            return
        }

        await runSyncLoop()
    }

    private func runSyncLoop() async {
        repeat {
            isSyncing = true
            needResync = false

            let reasons = pendingReasons
            pendingReasons.removeAll()

            logger.info("Sync started. reasons=\(String(describing: reasons), privacy: .public)")
            await performSyncWork(reasons)
            let finishedAt = dateProvider()
            logger.info("Sync finished at \(finishedAt.formatted(date: .abbreviated, time: .standard), privacy: .public)")
            if let onLastSyncAtUpdated {
                await onLastSyncAtUpdated(finishedAt)
            }

            isSyncing = false
        } while needResync || !pendingReasons.isEmpty
    }
}
