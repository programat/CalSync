//
//  AppViewModel.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case syncing
        case error(String?)
    }

    @Published var sourceCalendarId: String?
    @Published var childCalendarId: String?
    @Published var sourceCalendars: [CalendarInfo]
    @Published var childCalendars: [CalendarInfo]
    @Published var daysBack: Int
    @Published var daysForward: Int
    @Published var status: Status
    @Published var lastSyncAt: Date?
    @Published var createdCount: Int
    @Published var updatedCount: Int
    @Published var deletedCount: Int
    @Published var errors: [String]

    private let eventKitGateway: EventKitGateway
    private var didStart = false

    init(
        eventKitGateway: EventKitGateway? = nil,
        sourceCalendarId: String? = nil,
        childCalendarId: String? = nil,
        sourceCalendars: [CalendarInfo] = [],
        childCalendars: [CalendarInfo] = [],
        daysBack: Int = 30,
        daysForward: Int = 90,
        status: Status = .idle,
        lastSyncAt: Date? = nil,
        createdCount: Int = 0,
        updatedCount: Int = 0,
        deletedCount: Int = 0,
        errors: [String] = []
    ) {
        self.eventKitGateway = eventKitGateway ?? EventKitGatewayImpl()
        self.sourceCalendarId = sourceCalendarId
        self.childCalendarId = childCalendarId
        self.sourceCalendars = sourceCalendars
        self.childCalendars = childCalendars
        self.daysBack = daysBack
        self.daysForward = daysForward
        self.status = status
        self.lastSyncAt = lastSyncAt
        self.createdCount = createdCount
        self.updatedCount = updatedCount
        self.deletedCount = deletedCount
        self.errors = errors
    }

    func onAppStart() async {
        guard !didStart else { return }
        didStart = true
        await requestCalendarAccess()
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
            sourceCalendars = calendars
            childCalendars = calendars.filter(\.isWritable)
            validateSelectedCalendars()
            status = .idle
        } catch {
            let message = "Не удалось загрузить календари: \(error.localizedDescription)"
            status = .error(message)
            errors.append(message)
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
        let sourceIds = Set(sourceCalendars.map(\.id))
        let childIds = Set(childCalendars.map(\.id))

        if let sourceCalendarId, !sourceIds.contains(sourceCalendarId) {
            self.sourceCalendarId = nil
        }
        if let childCalendarId, !childIds.contains(childCalendarId) {
            self.childCalendarId = nil
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
}
