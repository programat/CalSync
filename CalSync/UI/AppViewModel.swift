//
//  AppViewModel.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import Foundation
import Combine
import CoreData

@MainActor
final class AppViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case syncing
        case error(String?)
    }

    @Published var sourceCalendarId: String? {
        didSet {
            settingsStore.sourceCalendarId = sourceCalendarId
            validateSelectedCalendars()
        }
    }
    @Published var childCalendarId: String? {
        didSet {
            settingsStore.childCalendarId = childCalendarId
            validateSelectedCalendars()
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
        }
    }
    @Published var daysForward: Int {
        didSet {
            settingsStore.daysForward = daysForward
        }
    }
    @Published var status: Status
    @Published var lastSyncAt: Date?
    @Published var totalFetchedCount: Int
    @Published var createdCount: Int
    @Published var updatedCount: Int
    @Published var deletedCount: Int
    @Published var errors: [String]

    private let eventKitGateway: EventKitGateway
    private let settingsStore: SettingsStore
    private var syncEngine: SyncEngine?
    private var didStart = false
    private var isValidatingCalendars = false

    init(
        eventKitGateway: EventKitGateway? = nil,
        settingsStore: SettingsStore? = nil,
        sourceCalendarId: String? = nil,
        childCalendarId: String? = nil,
        calendars: [CalendarInfo] = [],
        daysBack: Int? = nil,
        daysForward: Int? = nil,
        status: Status = .idle,
        lastSyncAt: Date? = nil,
        totalFetchedCount: Int = 0,
        createdCount: Int = 0,
        updatedCount: Int = 0,
        deletedCount: Int = 0,
        errors: [String] = []
    ) {
        let settingsStore = settingsStore ?? UserDefaultsSettingsStore()
        self.eventKitGateway = eventKitGateway ?? EventKitGatewayImpl()
        self.settingsStore = settingsStore
        self.sourceCalendarId = sourceCalendarId ?? settingsStore.sourceCalendarId
        self.childCalendarId = childCalendarId ?? settingsStore.childCalendarId
        self.calendars = calendars
        self.daysBack = daysBack ?? settingsStore.daysBack
        self.daysForward = daysForward ?? settingsStore.daysForward
        self.status = status
        self.lastSyncAt = lastSyncAt
        self.totalFetchedCount = totalFetchedCount
        self.createdCount = createdCount
        self.updatedCount = updatedCount
        self.deletedCount = deletedCount
        self.errors = errors

        let persistence = PersistenceController.shared
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
        await requestCalendarAccess()
        await syncEngine?.startObservingEventStoreChanges()
        await syncEngine?.startFallbackTimer()
    }

    func requestCalendarAccess() async {
        do {
            try await eventKitGateway.requestAccess()
            await loadCalendars()
        } catch {
            let message = accessErrorMessage(for: error)
            status = .error(message)
            errors.append(message)
        }
    }

    func loadCalendars() async {
        do {
            let calendars = try eventKitGateway.fetchCalendars()
            self.calendars = calendars
            validateSelectedCalendars()
            status = .idle
        } catch {
            let message = "Не удалось загрузить календари: \(error.localizedDescription)"
            status = .error(message)
            errors.append(message)
        }
    }

    func syncNow() {
        Task {
            await syncEngine?.syncNow()
        }
    }

    func resetSync() {
        Task {
            await syncEngine?.resetSync()
            await MainActor.run {
                totalFetchedCount = 0
                createdCount = 0
                updatedCount = 0
                deletedCount = 0
            }
        }
    }

    func placeholderSync() {
        status = .syncing
        lastSyncAt = Date()
        createdCount += 1
        errors.append("Sync placeholder at \(formattedTimestamp(lastSyncAt))")
        status = .idle
    }

    func placeholderReset() {
        status = .syncing
        createdCount = 0
        updatedCount = 0
        deletedCount = 0
        errors.append("Reset placeholder at \(formattedTimestamp(Date()))")
        status = .idle
    }

    private func formattedTimestamp(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .standard)
    }

    private func validateSelectedCalendars() {
        guard !isValidatingCalendars else { return }
        isValidatingCalendars = true
        defer { isValidatingCalendars = false }

        let calendarIds = Set(calendars.map(\.id))

        if let sourceCalendarId, !calendarIds.contains(sourceCalendarId) {
            self.sourceCalendarId = nil
        }
        if let childCalendarId, !calendarIds.contains(childCalendarId) {
            self.childCalendarId = nil
        }
        if
            let childCalendarId,
            let childCalendar = calendars.first(where: { $0.id == childCalendarId }),
            !childCalendar.isWritable
        {
            self.childCalendarId = nil
            errors.append("Выбранный Child календарь недоступен для записи.")
        }
        if let sourceCalendarId, let childCalendarId, sourceCalendarId == childCalendarId {
            self.childCalendarId = nil
            errors.append("Source и Child не могут быть одинаковыми.")
        }
    }

    private func accessErrorMessage(for error: Error) -> String {
        let hint = "Откройте System Settings -> Privacy & Security -> Calendars и выдайте доступ CalSync."
        let resetHint = "Если CalSync не появляется в списке, выполните в Terminal: tccutil reset Calendar com.tumashev.CalSync, затем нажмите \"Запросить доступ\" снова."
        if let gatewayError = error as? EventKitGatewayError, gatewayError == .accessDenied {
            return "Нет доступа к календарям. \(hint) \(resetHint)"
        }
        return "Не удалось запросить доступ к календарям: \(error.localizedDescription). \(hint) \(resetHint)"
    }

    private func applySyncUpdate(_ update: SyncEngineUpdate) {
        switch update {
        case .syncing:
            status = .syncing
        case .completed(let lastSyncAt, let totalFetched, let created, let updated):
            self.lastSyncAt = lastSyncAt
            totalFetchedCount = totalFetched
            createdCount = created
            updatedCount = updated
            status = .idle
        case .failed(let message):
            status = .error(message)
            errors.append(message)
        }
    }
}
