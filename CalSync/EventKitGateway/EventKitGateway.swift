//
//  EventKitGateway.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import Foundation

nonisolated protocol EventKitGateway {
    func requestAccess() async throws
    func fetchCalendars() throws -> [CalendarInfo]
    func fetchEvents(calendarId: String, from: Date, to: Date) throws -> [EventInfo]
    func getEvent(byId: String) throws -> EventInfo?
    func createEvent(in calendarId: String, payload: EventInfo) throws -> String
    func updateEvent(eventId: String, payload: EventInfo) throws
    func deleteEvent(eventId: String) throws
    func observeStoreChanges(_ handler: @escaping @Sendable () -> Void) -> AnyObject
}

nonisolated enum EventKitGatewayError: Error, Equatable, LocalizedError {
    case accessDenied
    case calendarNotFound
    case eventNotFound
    case missingEventIdentifier

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Нет доступа к календарям."
        case .calendarNotFound:
            return "Выбранный календарь недоступен."
        case .eventNotFound:
            return "Событие не найдено."
        case .missingEventIdentifier:
            return "Не удалось получить идентификатор события."
        }
    }
}
