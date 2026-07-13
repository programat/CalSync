//
//  AppViewModel.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import Foundation
import Combine
import CoreData
import os

@MainActor
final class AppViewModel: ObservableObject {
    nonisolated enum Status: Equatable, Sendable {
        case idle
        case syncing
        case error(String?)
    }

    @Published var sourceCalendarId: String? {
        didSet {
            settingsStore.sourceCalendarId = sourceCalendarId
            validateSelectedCalendars()
            requestSyncAfterSettingsChangeIfReady()
        }
    }
    @Published var childCalendarId: String? {
        didSet {
            settingsStore.childCalendarId = childCalendarId
            validateSelectedCalendars()
            requestSyncAfterSettingsChangeIfReady()
        }
    }
    @Published var calendars: [CalendarInfo] {
        didSet {
            validateSelectedCalendars()
        }
    }
    @Published var daysBack: Int {
        didSet {
            settingsStore.daysBack = daysBack
            requestSyncAfterSettingsChangeIfReady()
        }
    }
    @Published var daysForward: Int {
        didSet {
            settingsStore.daysForward = daysForward
            requestSyncAfterSettingsChangeIfReady()
        }
    }
    @Published var excludeCanceledEventsByStatus: Bool {
        didSet {
            settingsStore.excludeCanceledEventsByStatus = excludeCanceledEventsByStatus
            requestSyncAfterSettingsChangeIfReady()
        }
    }
    @Published var useCanceledTitlePrefixFilter: Bool {
        didSet {
            settingsStore.useCanceledTitlePrefixFilter = useCanceledTitlePrefixFilter
            requestSyncAfterSettingsChangeIfReady()
        }
    }
    @Published private(set) var canceledTitlePrefixes: [String] {
        didSet {
            settingsStore.canceledTitlePrefixes = canceledTitlePrefixes
            requestSyncAfterSettingsChangeIfReady()
        }
    }
    @Published var isAutoSyncEnabled: Bool {
        didSet {
            settingsStore.isAutoSyncEnabled = isAutoSyncEnabled
            reconfigureAutoSync(runImmediatelyWhenEnabled: isAutoSyncEnabled)
        }
    }
    @Published var autoSyncIntervalMinutes: Int {
        didSet {
            let clampedValue = UserDefaultsSettingsStore.clampAutoSyncIntervalMinutes(
                autoSyncIntervalMinutes
            )
            if autoSyncIntervalMinutes != clampedValue {
                autoSyncIntervalMinutes = clampedValue
            }
            settingsStore.autoSyncIntervalMinutes = autoSyncIntervalMinutes
            reconfigureAutoSync(runImmediatelyWhenEnabled: false)
        }
    }
    @Published var status: Status
    @Published var lastSuccessfulSyncAt: Date?
    @Published var lastSyncAttemptAt: Date?
    @Published var lastSyncOutcome: SyncAttemptSnapshot.Outcome?
    @Published var lastSyncReasons: Set<SyncReason>
    @Published var totalFetchedCount: Int
    @Published var createdCount: Int
    @Published var updatedCount: Int
    @Published var deletedCount: Int
    @Published var errors: [String]

    private let eventKitGateway: EventKitGateway
    private let settingsStore: SettingsStore
    private let diagnosticsStore: SyncDiagnosticsStore
    private var syncEngine: SyncEngine?
    private var didStart = false
    private var isValidatingCalendars = false
    private let logger = Logger(subsystem: "CalSync", category: "AppViewModel")

    init(
        eventKitGateway: EventKitGateway? = nil,
        settingsStore: SettingsStore? = nil,
        diagnosticsStore: SyncDiagnosticsStore? = nil,
        persistenceController: PersistenceController? = nil
    ) {
        let settingsStore = settingsStore ?? UserDefaultsSettingsStore()
        let diagnosticsStore = diagnosticsStore ?? UserDefaultsSyncDiagnosticsStore()
        let storedAttempt = diagnosticsStore.lastAttempt
        self.eventKitGateway = eventKitGateway ?? EventKitGatewayImpl()
        self.settingsStore = settingsStore
        self.diagnosticsStore = diagnosticsStore
        self.sourceCalendarId = settingsStore.sourceCalendarId
        self.childCalendarId = settingsStore.childCalendarId
        self.calendars = []
        self.daysBack = settingsStore.daysBack
        self.daysForward = settingsStore.daysForward
        self.excludeCanceledEventsByStatus = settingsStore.excludeCanceledEventsByStatus
        self.useCanceledTitlePrefixFilter = settingsStore.useCanceledTitlePrefixFilter
        self.canceledTitlePrefixes = CanceledTitlePrefixRules.normalized(
            settingsStore.canceledTitlePrefixes
        )
        self.isAutoSyncEnabled = settingsStore.isAutoSyncEnabled
        self.autoSyncIntervalMinutes = UserDefaultsSettingsStore.clampAutoSyncIntervalMinutes(
            settingsStore.autoSyncIntervalMinutes
        )
        if storedAttempt?.outcome == .failed {
            self.status = .error("Последняя попытка синхронизации завершилась ошибкой.")
        } else {
            self.status = .idle
        }
        self.lastSuccessfulSyncAt = diagnosticsStore.lastSuccessfulSyncAt
        self.lastSyncAttemptAt = storedAttempt?.timestamp
        self.lastSyncOutcome = storedAttempt?.outcome
        self.lastSyncReasons = storedAttempt?.reasons ?? []
        self.totalFetchedCount = storedAttempt?.metrics?.totalFetched ?? 0
        self.createdCount = storedAttempt?.metrics?.created ?? 0
        self.updatedCount = storedAttempt?.metrics?.updated ?? 0
        self.deletedCount = storedAttempt?.metrics?.deleted ?? 0
        self.errors = []

        let persistence = persistenceController ?? PersistenceController.shared
        let linkRepo = LinkRepository(context: persistence.container.viewContext)
        let errorRepo = ErrorRepository(context: persistence.container.viewContext)
        self.syncEngine = SyncEngine(
            gateway: self.eventKitGateway,
            linkRepo: linkRepo,
            errorRepo: errorRepo,
            settings: settingsStore,
            onUpdate: { [weak self] update in
                self?.applySyncUpdate(update)
            }
        )
    }

    func onAppStart() async {
        guard !didStart else { return }
        didStart = true
        await requestCalendarAccess(scheduleAutoSyncOnSuccess: false)
        await syncEngine?.configureAutoSyncFromSettings()
        if isAutoSyncEnabled, isSyncConfigurationReady {
            await syncEngine?.syncNow(reason: .appLaunch)
        }
    }

    func requestCalendarAccess(scheduleAutoSyncOnSuccess: Bool = true) async {
        do {
            try await eventKitGateway.requestAccess()
            await loadCalendars()
            if scheduleAutoSyncOnSuccess {
                requestSyncAfterSettingsChangeIfReady()
            }
        } catch {
            let message = accessErrorMessage(for: error)
            status = .error(message)
            errors.append(message)
        }
    }

    func loadCalendars() async {
        do {
            let calendars = try eventKitGateway.fetchCalendars()
            if lastSyncOutcome == .failed {
                status = .error("Последняя попытка синхронизации завершилась ошибкой.")
            } else {
                status = .idle
            }
            self.calendars = calendars
        } catch {
            let message = "Не удалось загрузить календари: \(error.localizedDescription)"
            status = .error(message)
            errors.append(message)
            logger.error("Failed to load calendars: \(message, privacy: .public)")
        }
    }

    func syncNow() {
        Task {
            await syncEngine?.syncNow()
        }
    }

    func resetSync() {
        Task { @MainActor in
            await syncEngine?.resetSync()
            status = .idle
            lastSuccessfulSyncAt = nil
            lastSyncAttemptAt = nil
            lastSyncOutcome = nil
            lastSyncReasons = []
            totalFetchedCount = 0
            createdCount = 0
            updatedCount = 0
            deletedCount = 0
            errors.removeAll()
            diagnosticsStore.clear()
        }
    }

    func canAddCanceledTitlePrefix(_ prefix: String) -> Bool {
        CanceledTitlePrefixRules.adding(prefix, to: canceledTitlePrefixes) != nil
    }

    @discardableResult
    func addCanceledTitlePrefix(_ prefix: String) -> Bool {
        guard let updatedPrefixes = CanceledTitlePrefixRules.adding(
            prefix,
            to: canceledTitlePrefixes
        ) else {
            return false
        }
        canceledTitlePrefixes = updatedPrefixes
        return true
    }

    func removeCanceledTitlePrefix(_ prefix: String) {
        canceledTitlePrefixes.removeAll { $0 == prefix }
    }

    private var isSyncConfigurationReady: Bool {
        guard
            let sourceCalendarId,
            let childCalendarId,
            sourceCalendarId != childCalendarId,
            calendars.contains(where: { $0.id == sourceCalendarId }),
            let childCalendar = calendars.first(where: { $0.id == childCalendarId }),
            childCalendar.isWritable
        else {
            return false
        }
        return true
    }

    private func requestSyncAfterSettingsChangeIfReady() {
        guard didStart, isAutoSyncEnabled, isSyncConfigurationReady else {
            return
        }
        Task {
            await syncEngine?.requestSync(reason: .settingsChanged)
        }
    }

    private func reconfigureAutoSync(runImmediatelyWhenEnabled: Bool) {
        guard didStart else {
            return
        }
        let shouldRunImmediately = runImmediatelyWhenEnabled && isSyncConfigurationReady
        Task {
            await syncEngine?.configureAutoSyncFromSettings()
            if shouldRunImmediately {
                await syncEngine?.syncNow(reason: .autoSyncEnabled)
            }
        }
    }

    @discardableResult
    private func validateSelectedCalendars() -> Bool {
        guard !isValidatingCalendars else { return true }
        isValidatingCalendars = true
        defer { isValidatingCalendars = false }

        let calendarIds = Set(calendars.map(\.id))
        var isValid = true

        if let sourceCalendarId, !calendarIds.contains(sourceCalendarId) {
            self.sourceCalendarId = nil
            setValidationError("Source календарь недоступен.")
            isValid = false
        }
        if let childCalendarId, !calendarIds.contains(childCalendarId) {
            self.childCalendarId = nil
            setValidationError("Child календарь недоступен.")
            isValid = false
        }
        if
            let childCalendarId,
            let childCalendar = calendars.first(where: { $0.id == childCalendarId }),
            !childCalendar.isWritable
        {
            self.childCalendarId = nil
            setValidationError("Child календарь недоступен для записи.")
            isValid = false
        }
        if let sourceCalendarId, let childCalendarId, sourceCalendarId == childCalendarId {
            self.childCalendarId = nil
            setValidationError("Source и Child календари должны отличаться.")
            isValid = false
        }
        return isValid
    }

    private func setValidationError(_ message: String) {
        status = .error(message)
        if errors.last != message {
            errors.append(message)
        }
        logger.error("Calendar validation failed: \(message, privacy: .public)")
    }

    private func accessErrorMessage(for error: Error) -> String {
        let hint = "Разрешите CalSync доступ: Системные настройки → Конфиденциальность и безопасность → Календари."
        if let gatewayError = error as? EventKitGatewayError, gatewayError == .accessDenied {
            return "Нет доступа к календарям. \(hint)"
        }
        return "Не удалось запросить доступ к календарям: \(error.localizedDescription). \(hint)"
    }

    func applySyncUpdate(_ update: SyncEngineUpdate) {
        switch update {
        case .syncing(let startedAt, let reasons):
            status = .syncing
            clearSyncCounts()
            recordSyncAttempt(timestamp: startedAt, reasons: reasons, outcome: .running)
        case .completed(
            let finishedAt,
            let reasons,
            let totalFetched,
            let created,
            let updated,
            let deleted
        ):
            let metrics = SyncAttemptSnapshot.Metrics(
                totalFetched: totalFetched,
                created: created,
                updated: updated,
                deleted: deleted
            )
            lastSuccessfulSyncAt = finishedAt
            diagnosticsStore.lastSuccessfulSyncAt = finishedAt
            recordSyncAttempt(
                timestamp: finishedAt,
                reasons: reasons,
                outcome: .succeeded,
                metrics: metrics
            )
            totalFetchedCount = metrics.totalFetched
            createdCount = metrics.created
            updatedCount = metrics.updated
            deletedCount = metrics.deleted
            status = .idle
        case .failed(let finishedAt, let reasons, let message):
            clearSyncCounts()
            recordSyncAttempt(timestamp: finishedAt, reasons: reasons, outcome: .failed)
            status = .error(message)
            errors.append(message)
        }
    }

    private func recordSyncAttempt(
        timestamp: Date,
        reasons: Set<SyncReason>,
        outcome: SyncAttemptSnapshot.Outcome,
        metrics: SyncAttemptSnapshot.Metrics? = nil
    ) {
        lastSyncAttemptAt = timestamp
        lastSyncReasons = reasons
        lastSyncOutcome = outcome
        diagnosticsStore.lastAttempt = SyncAttemptSnapshot(
            timestamp: timestamp,
            reasons: reasons,
            outcome: outcome,
            metrics: metrics
        )
    }

    private func clearSyncCounts() {
        totalFetchedCount = 0
        createdCount = 0
        updatedCount = 0
        deletedCount = 0
    }
}
