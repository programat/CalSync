//
//  SyncEngine.swift
//  CalSync
//
//  Created by Codex on 09.02.2026.
//

import Foundation
import CryptoKit
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
    case completed(lastSyncAt: Date, totalFetched: Int, created: Int, updated: Int, deleted: Int)
    case failed(message: String)
}

nonisolated enum SyncEngineError: LocalizedError {
    case calendarsNotSelected
    case sourceCalendarUnavailable
    case childCalendarUnavailable
    case childCalendarReadOnly

    var errorDescription: String? {
        switch self {
        case .calendarsNotSelected:
            return "Source и Child календари должны быть выбраны."
        case .sourceCalendarUnavailable:
            return "Выбранный Source календарь недоступен."
        case .childCalendarUnavailable:
            return "Выбранный Child календарь недоступен."
        case .childCalendarReadOnly:
            return "Выбранный Child календарь недоступен для записи."
        }
    }
}

actor SyncEngine {
    typealias DateProvider = @Sendable () -> Date
    typealias UpdateHandler = @MainActor @Sendable (SyncEngineUpdate) async -> Void

    struct SyncResult: Sendable {
        let totalFetched: Int
        let created: Int
        let updated: Int
        let deleted: Int
    }

    private struct LinkState: Sendable {
        let id: UUID?
        let sourceEventId: String?
        let sourceCalendarItemId: String?
        let sourceOccurrenceDate: Date?
        let sourceStartLastSeen: Date?
        let childEventId: String?
        let lastSyncHash: String?
    }

    private struct EventProcessResult {
        let created: Int
        let updated: Int
    }

    typealias SyncWork = @Sendable (Set<SyncReason>) async throws -> SyncResult

    private let gateway: EventKitGateway
    private let linkRepo: LinkRepository
    private let errorRepo: ErrorRepository
    private let settings: SettingsStore
    private let dateProvider: DateProvider
    private let clock: any SyncEngineClock
    private let debounceDuration: Duration
    private let fallbackInterval: Duration
    private let eventStoreChangeSuppressionInterval: TimeInterval
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
    private var suppressEventStoreChangesUntil: Date?

    init(
        gateway: EventKitGateway,
        linkRepo: LinkRepository,
        errorRepo: ErrorRepository,
        settings: SettingsStore,
        dateProvider: @escaping DateProvider = Date.init,
        clock: any SyncEngineClock = ContinuousSyncEngineClock(),
        debounceDuration: Duration = .seconds(2),
        fallbackInterval: Duration = .seconds(15 * 60),
        eventStoreChangeSuppressionInterval: TimeInterval = 2,
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
        self.eventStoreChangeSuppressionInterval = eventStoreChangeSuppressionInterval
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
            let links = try await fetchAllLinkStates()
            for link in links {
                guard let childEventId = link.childEventId, !childEventId.isEmpty else {
                    continue
                }
                do {
                    try gateway.deleteEvent(eventId: childEventId)
                } catch let gatewayError as EventKitGatewayError where gatewayError == .eventNotFound {
                    continue
                }
            }

            try await MainActor.run {
                try linkRepo.deleteAll()
                try errorRepo.deleteAll()
            }
            pendingReasons.removeAll()
            needResync = false
            debounceTask?.cancel()
            debounceTask = nil
            suppressEventStoreChangesUntil = nil
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
                await self.handleEventStoreChanged()
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

    private func handleEventStoreChanged() {
        if isSyncing {
            return
        }
        if let suppressUntil = suppressEventStoreChangesUntil, dateProvider() < suppressUntil {
            return
        }
        requestSync(reason: .eventStoreChanged)
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
                let result = try await sync(reasons: reasons)
                let finishedAt = dateProvider()
                suppressEventStoreChangesUntil = finishedAt.addingTimeInterval(eventStoreChangeSuppressionInterval)
                logger.info("Sync finished at \(finishedAt.formatted(date: .abbreviated, time: .standard), privacy: .public)")
                if let onUpdate {
                    await onUpdate(
                        .completed(
                            lastSyncAt: finishedAt,
                            totalFetched: result.totalFetched,
                            created: result.created,
                            updated: result.updated,
                            deleted: result.deleted
                        )
                    )
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

    private func sync(reasons: Set<SyncReason>) async throws -> SyncResult {
        if let syncWorkOverride {
            return try await syncWorkOverride(reasons)
        }

        guard
            let sourceCalendarId = settings.sourceCalendarId,
            let childCalendarId = settings.childCalendarId
        else {
            throw SyncEngineError.calendarsNotSelected
        }

        let calendars = try await performGatewayOperation(context: "fetchCalendars") {
            try gateway.fetchCalendars()
        }
        guard calendars.contains(where: { $0.id == sourceCalendarId }) else {
            throw SyncEngineError.sourceCalendarUnavailable
        }
        guard let childCalendar = calendars.first(where: { $0.id == childCalendarId }) else {
            throw SyncEngineError.childCalendarUnavailable
        }
        guard childCalendar.isWritable else {
            throw SyncEngineError.childCalendarReadOnly
        }

        let window = Self.computeWindow(
            now: dateProvider(),
            daysBack: settings.daysBack,
            daysForward: settings.daysForward,
            calendar: calendar
        )
        let sourceEvents = try await performGatewayOperation(context: "fetchEvents") {
            try gateway.fetchEvents(
                calendarId: sourceCalendarId,
                from: window.from,
                to: window.to
            )
        }

        let lastSeenInSourceAt = dateProvider()
        let sourceEventsByFallback = buildSourceEventsByFallbackKey(sourceEvents)
        let sourceEventIdsInWindow = Set(
            sourceEvents
                .filter { !$0.isRecurring && $0.occurrenceDate == nil }
                .compactMap(\.eventId)
                .filter { !$0.isEmpty }
        )

        var createdCount = 0
        var updatedCount = 0
        var deletedCount = 0
        var matchedCount = 0
        var unmatchedCount = 0

        for sourceEvent in sourceEvents {
            let existingLink = try await findLinkState(for: sourceEvent)
            let result = try await processSourceEvent(
                sourceEvent,
                existing: existingLink,
                sourceCalendarId: sourceCalendarId,
                childCalendarId: childCalendarId,
                lastSeenInSourceAt: lastSeenInSourceAt
            )

            createdCount += result.created
            updatedCount += result.updated
            if existingLink == nil {
                unmatchedCount += 1
            } else {
                matchedCount += 1
            }
        }

        let allLinks = try await fetchAllLinkStates()
        for link in allLinks {
            if linkIsRepresentedInWindow(
                link,
                sourceEventIdsInWindow: sourceEventIdsInWindow,
                sourceEventsByFallback: sourceEventsByFallback
            ) {
                continue
            }

            let sourceById = try await fetchSourceEventByIdentifier(link.sourceEventId)
            if let sourceById, sourceEventMatchesLink(sourceById, link: link) {
                let result = try await processSourceEvent(
                    sourceById,
                    existing: link,
                    sourceCalendarId: sourceCalendarId,
                    childCalendarId: childCalendarId,
                    lastSeenInSourceAt: lastSeenInSourceAt
                )
                createdCount += result.created
                updatedCount += result.updated
                continue
            }

            let fallbackEvent = sourceEventByFallback(link: link, sourceEventsByFallback: sourceEventsByFallback)
            if let fallbackEvent {
                let result = try await processSourceEvent(
                    fallbackEvent,
                    existing: link,
                    sourceCalendarId: sourceCalendarId,
                    childCalendarId: childCalendarId,
                    lastSeenInSourceAt: lastSeenInSourceAt
                )
                createdCount += result.created
                updatedCount += result.updated
                continue
            }

            try await deleteLinkAndChildEventIfNeeded(link)
            deletedCount += 1
        }

        logger.info(
            "Fetched source events=\(sourceEvents.count, privacy: .public), matched=\(matchedCount, privacy: .public), unmatched=\(unmatchedCount, privacy: .public), created=\(createdCount, privacy: .public), updated=\(updatedCount, privacy: .public), deleted=\(deletedCount, privacy: .public)"
        )
        return SyncResult(
            totalFetched: sourceEvents.count,
            created: createdCount,
            updated: updatedCount,
            deleted: deletedCount
        )
    }

    private func syncErrorMessage(for error: Error) -> String {
        if let gatewayError = error as? EventKitGatewayError, let message = gatewayError.errorDescription {
            return message
        }

        if let localizedError = error as? LocalizedError, let message = localizedError.errorDescription {
            return message
        }
        return error.localizedDescription
    }

    private func processSourceEvent(
        _ sourceEvent: EventInfo,
        existing: LinkState?,
        sourceCalendarId: String,
        childCalendarId: String,
        lastSeenInSourceAt: Date
    ) async throws -> EventProcessResult {
        let mirrorPayload = Self.makeMirrorPayload(from: sourceEvent)
        let payloadHash = Self.hashKeyFields(for: mirrorPayload)

        var nextChildEventId = existing?.childEventId ?? ""
        var created = 0
        var updated = 0

        let childEvent: EventInfo? = try await performGatewayOperation(context: "getChildEvent") {
            if nextChildEventId.isEmpty {
                return Optional<EventInfo>.none
            }
            return try gateway.getEvent(byId: nextChildEventId)
        }

        if childEvent == nil {
            nextChildEventId = try await performGatewayOperation(context: "createEvent") {
                try gateway.createEvent(in: childCalendarId, payload: mirrorPayload)
            }
            created += 1
        } else if (existing?.lastSyncHash ?? "") != payloadHash {
            try await performGatewayOperation(context: "updateEvent") {
                try gateway.updateEvent(eventId: nextChildEventId, payload: mirrorPayload)
            }
            updated += 1
        }

        try await upsertLink(
            existing: existing,
            sourceCalendarId: sourceCalendarId,
            childCalendarId: childCalendarId,
            sourceEvent: sourceEvent,
            childEventId: nextChildEventId,
            lastSeenInSourceAt: lastSeenInSourceAt,
            lastSyncHash: payloadHash
        )

        return EventProcessResult(created: created, updated: updated)
    }

    private func findLinkState(for sourceEvent: EventInfo) async throws -> LinkState? {
        try await MainActor.run { [linkRepo] in
            guard let link = try linkRepo.findLink(for: sourceEvent) else {
                return Optional<LinkState>.none
            }
            return LinkState(
                id: link.id,
                sourceEventId: link.sourceEventId,
                sourceCalendarItemId: link.sourceCalendarItemId,
                sourceOccurrenceDate: link.sourceOccurrenceDate,
                sourceStartLastSeen: link.sourceStartLastSeen,
                childEventId: link.childEventId,
                lastSyncHash: link.lastSyncHash
            )
        }
    }

    private func fetchAllLinkStates() async throws -> [LinkState] {
        try await MainActor.run { [linkRepo] in
            let links = try linkRepo.fetchAll()
            return links.map { link in
                LinkState(
                    id: link.id,
                    sourceEventId: link.sourceEventId,
                    sourceCalendarItemId: link.sourceCalendarItemId,
                    sourceOccurrenceDate: link.sourceOccurrenceDate,
                    sourceStartLastSeen: link.sourceStartLastSeen,
                    childEventId: link.childEventId,
                    lastSyncHash: link.lastSyncHash
                )
            }
        }
    }

    private func fetchSourceEventByIdentifier(_ sourceEventId: String?) async throws -> EventInfo? {
        guard let sourceEventId, !sourceEventId.isEmpty else {
            return nil
        }
        return try await performGatewayOperation(context: "getSourceEvent") {
            try gateway.getEvent(byId: sourceEventId)
        }
    }

    private func buildSourceEventsByFallbackKey(_ sourceEvents: [EventInfo]) -> [SourceFallbackKey: EventInfo] {
        var byFallback: [SourceFallbackKey: EventInfo] = [:]
        for sourceEvent in sourceEvents {
            guard let sourceCalendarItemId = sourceEvent.calendarItemId else {
                continue
            }
            let fallback = SourceFallbackKey(
                sourceCalendarItemId: sourceCalendarItemId,
                sourceDate: sourceEvent.occurrenceDate ?? sourceEvent.startDate
            )
            byFallback[fallback] = sourceEvent
        }
        return byFallback
    }

    private func sourceEventByFallback(
        link: LinkState,
        sourceEventsByFallback: [SourceFallbackKey: EventInfo]
    ) -> EventInfo? {
        guard
            let sourceCalendarItemId = link.sourceCalendarItemId,
            let sourceDate = link.sourceOccurrenceDate ?? link.sourceStartLastSeen
        else {
            return nil
        }

        let fallbackKey = SourceFallbackKey(
            sourceCalendarItemId: sourceCalendarItemId,
            sourceDate: sourceDate
        )
        return sourceEventsByFallback[fallbackKey]
    }

    private func linkIsRepresentedInWindow(
        _ link: LinkState,
        sourceEventIdsInWindow: Set<String>,
        sourceEventsByFallback: [SourceFallbackKey: EventInfo]
    ) -> Bool {
        if sourceEventByFallback(link: link, sourceEventsByFallback: sourceEventsByFallback) != nil {
            return true
        }

        guard
            let sourceEventId = link.sourceEventId,
            !sourceEventId.isEmpty
        else {
            return false
        }
        return sourceEventIdsInWindow.contains(sourceEventId)
    }

    private func sourceEventMatchesLink(_ sourceEvent: EventInfo, link: LinkState) -> Bool {
        if link.sourceOccurrenceDate == nil {
            if let linkSourceEventId = link.sourceEventId, !linkSourceEventId.isEmpty {
                return sourceEvent.eventId == linkSourceEventId
            }
            guard let linkCalendarItemId = link.sourceCalendarItemId else {
                return false
            }
            return sourceEvent.calendarItemId == linkCalendarItemId
        }

        guard let linkCalendarItemId = link.sourceCalendarItemId else {
            return false
        }
        guard sourceEvent.calendarItemId == linkCalendarItemId else {
            return false
        }

        let linkSourceDate = link.sourceOccurrenceDate
        let sourceDate = sourceEvent.occurrenceDate ?? sourceEvent.startDate
        return sourceDate == linkSourceDate
    }

    private func deleteLinkAndChildEventIfNeeded(_ link: LinkState) async throws {
        if let childEventId = link.childEventId, !childEventId.isEmpty {
            try await performGatewayOperation(context: "deleteEvent") {
                try gateway.deleteEvent(eventId: childEventId)
            }
        }

        try await MainActor.run { [linkRepo] in
            guard let linkId = link.id else {
                return
            }
            try linkRepo.delete(id: linkId)
        }
    }

    private func performGatewayOperation<T>(
        context: String,
        _ operation: () throws -> T
    ) async throws -> T {
        do {
            return try operation()
        } catch {
            await persistSyncErrorIfNeeded(error, context: context)
            throw error
        }
    }

    private func persistSyncErrorIfNeeded(_ error: Error, context: String) async {
        guard shouldPersistGatewayError(error) else {
            return
        }

        let message = syncErrorMessage(for: error)
        do {
            try await MainActor.run { [errorRepo] in
                _ = try errorRepo.addError(
                    timestamp: dateProvider(),
                    message: message,
                    context: context
                )
                try errorRepo.trimTo(limit: 20)
            }
        } catch {
            logger.error("Failed to persist sync error: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func shouldPersistGatewayError(_ error: Error) -> Bool {
        if error is EventKitGatewayError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == "EKErrorDomain" || nsError.domain.contains("EventKit")
    }

    private func upsertLink(
        existing: LinkState?,
        sourceCalendarId: String,
        childCalendarId: String,
        sourceEvent: EventInfo,
        childEventId: String,
        lastSeenInSourceAt: Date,
        lastSyncHash: String
    ) async throws {
        let payload = SyncedEventLinkPayload(
            id: existing?.id ?? UUID(),
            sourceCalendarId: sourceCalendarId,
            childCalendarId: childCalendarId,
            sourceEventId: sourceEvent.eventId,
            sourceCalendarItemId: sourceEvent.calendarItemId,
            sourceOccurrenceDate: sourceEvent.occurrenceDate,
            sourceStartLastSeen: sourceEvent.startDate,
            sourceEndLastSeen: sourceEvent.endDate,
            childEventId: childEventId,
            lastSyncedAt: lastSeenInSourceAt,
            lastSeenInSourceAt: lastSeenInSourceAt,
            lastSyncHash: lastSyncHash
        )

        try await MainActor.run { [linkRepo] in
            if let linkId = existing?.id {
                if try linkRepo.update(id: linkId, payload: payload) == nil {
                    _ = try linkRepo.create(payload)
                }
            } else {
                _ = try linkRepo.create(payload)
            }
        }
    }

    nonisolated static func makeMirrorPayload(from source: EventInfo) -> EventInfo {
        EventInfo(
            eventId: nil,
            calendarItemId: nil,
            occurrenceDate: nil,
            isRecurring: false,
            title: source.title,
            notes: source.notes,
            location: source.location,
            structuredLocation: source.structuredLocation,
            startDate: source.startDate,
            endDate: source.endDate,
            isAllDay: source.isAllDay,
            timeZone: source.timeZone,
            availability: source.availability,
            status: source.status,
            alarms: [],
            url: source.url
        )
    }

    nonisolated static func hashKeyFields(for payload: EventInfo) -> String {
        var fields: [String] = []
        fields.append(payload.title)
        fields.append(payload.notes ?? "")
        fields.append(payload.location ?? "")

        if let structuredLocation = payload.structuredLocation {
            fields.append(structuredLocation.title)
            fields.append(String(structuredLocation.latitude ?? 0))
            fields.append(String(structuredLocation.longitude ?? 0))
            fields.append(String(structuredLocation.radius ?? 0))
        } else {
            fields.append("")
        }

        fields.append(String(payload.startDate.timeIntervalSince1970))
        fields.append(String(payload.endDate.timeIntervalSince1970))
        fields.append(payload.isAllDay ? "1" : "0")
        fields.append(payload.timeZone?.identifier ?? "")
        fields.append(string(from: payload.availability))
        fields.append(string(from: payload.status))
        fields.append(payload.url?.absoluteString ?? "")

        for alarm in payload.alarms {
            fields.append(String(alarm.absoluteDate?.timeIntervalSince1970 ?? 0))
            fields.append(String(alarm.relativeOffset ?? 0))
            if let structuredLocation = alarm.structuredLocation {
                fields.append(structuredLocation.title)
                fields.append(String(structuredLocation.latitude ?? 0))
                fields.append(String(structuredLocation.longitude ?? 0))
                fields.append(String(structuredLocation.radius ?? 0))
            } else {
                fields.append("")
            }
            fields.append(string(from: alarm.proximity))
        }

        let digest = SHA256.hash(data: Data(fields.joined(separator: "|").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static func string(from availability: EventAvailability) -> String {
        switch availability {
        case .notSupported:
            return "notSupported"
        case .busy:
            return "busy"
        case .free:
            return "free"
        case .tentative:
            return "tentative"
        case .unavailable:
            return "unavailable"
        }
    }

    nonisolated private static func string(from status: EventStatus) -> String {
        switch status {
        case .none:
            return "none"
        case .confirmed:
            return "confirmed"
        case .tentative:
            return "tentative"
        case .canceled:
            return "canceled"
        }
    }

    nonisolated private static func string(from proximity: AlarmProximity) -> String {
        switch proximity {
        case .none:
            return "none"
        case .enter:
            return "enter"
        case .leave:
            return "leave"
        }
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
