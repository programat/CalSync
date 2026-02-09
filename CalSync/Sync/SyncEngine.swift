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

nonisolated enum SyncEngineUpdate: Equatable, Sendable {
    case syncing
    case completed(lastSyncAt: Date, totalFetched: Int)
    case failed(message: String)
}

nonisolated enum SyncEngineError: LocalizedError {
    case calendarsNotSelected

    var errorDescription: String? {
        switch self {
        case .calendarsNotSelected:
            return "Source и Child календари должны быть выбраны."
        }
    }
}

actor SyncEngine {
    typealias DateProvider = @Sendable () -> Date
    typealias UpdateHandler = @MainActor @Sendable (SyncEngineUpdate) async -> Void
    typealias SyncWork = @Sendable (Set<SyncReason>) async throws -> Int

    private let gateway: EventKitGateway
    private let linkRepo: LinkRepository
    private let errorRepo: ErrorRepository
    private let settings: SettingsStore
    private let dateProvider: DateProvider
    private let clock: any SyncEngineClock
    private let debounceDuration: Duration
    private let fallbackInterval: Duration
    private let calendar: Calendar
    private let onUpdate: UpdateHandler?
    private let syncWorkOverride: SyncWork?
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
        calendar: Calendar = .current,
        onUpdate: UpdateHandler? = nil,
        syncWorkOverride: SyncWork? = nil
    ) {
        self.gateway = gateway
        self.linkRepo = linkRepo
        self.errorRepo = errorRepo
        self.settings = settings
        self.dateProvider = dateProvider
        self.clock = clock
        self.debounceDuration = debounceDuration
        self.fallbackInterval = fallbackInterval
        self.calendar = calendar
        self.onUpdate = onUpdate
        self.syncWorkOverride = syncWorkOverride
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

            if let onUpdate {
                await onUpdate(.syncing)
            }

            do {
                logger.info("Sync started. reasons=\(String(describing: reasons), privacy: .public)")
                let totalFetched = try await sync(reasons: reasons)
                let finishedAt = dateProvider()
                logger.info("Sync finished at \(finishedAt.formatted(date: .abbreviated, time: .standard), privacy: .public)")
                if let onUpdate {
                    await onUpdate(.completed(lastSyncAt: finishedAt, totalFetched: totalFetched))
                }
            } catch {
                let message = syncErrorMessage(for: error)
                logger.error("Sync failed: \(message, privacy: .public)")
                if let onUpdate {
                    await onUpdate(.failed(message: message))
                }
            }

            isSyncing = false
        } while needResync || !pendingReasons.isEmpty
    }

    private func sync(reasons: Set<SyncReason>) async throws -> Int {
        if let syncWorkOverride {
            return try await syncWorkOverride(reasons)
        }

        guard
            let sourceCalendarId = settings.sourceCalendarId,
            let childCalendarId = settings.childCalendarId
        else {
            throw SyncEngineError.calendarsNotSelected
        }
        _ = childCalendarId

        let window = Self.computeWindow(
            now: dateProvider(),
            daysBack: settings.daysBack,
            daysForward: settings.daysForward,
            calendar: calendar
        )
        let sourceEvents = try gateway.fetchEvents(
            calendarId: sourceCalendarId,
            from: window.from,
            to: window.to
        )
        return sourceEvents.count
    }

    private func syncErrorMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError, let message = localizedError.errorDescription {
            return message
        }
        return error.localizedDescription
    }

    nonisolated static func computeWindow(
        now: Date,
        daysBack: Int,
        daysForward: Int,
        calendar: Calendar = .current
    ) -> (from: Date, to: Date) {
        let safeDaysBack = max(0, daysBack)
        let safeDaysForward = max(0, daysForward)

        let fromAnchor = calendar.date(byAdding: .day, value: -safeDaysBack, to: now) ?? now
        let toAnchor = calendar.date(byAdding: .day, value: safeDaysForward, to: now) ?? now

        let from = calendar.startOfDay(for: fromAnchor)
        let toDayInterval = calendar.dateInterval(of: .day, for: toAnchor)
        let to = (toDayInterval?.end ?? toAnchor).addingTimeInterval(-1)
        return (from: from, to: to)
    }
}
