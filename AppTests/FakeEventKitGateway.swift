//
//  FakeEventKitGateway.swift
//  CalSyncTests
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import Foundation
@testable import CalSync

final class FakeEventKitGateway: EventKitGateway {
    func requestAccess() async throws {
    }

    func fetchCalendars() throws -> [CalendarInfo] {
        []
    }

    func fetchEvents(calendarId: String, from: Date, to: Date) throws -> [EventInfo] {
        []
    }

    func getEvent(byId: String) throws -> EventInfo? {
        nil
    }

    func createEvent(in calendarId: String, payload: EventInfo) throws -> String {
        ""
    }

    func updateEvent(eventId: String, payload: EventInfo) throws {
    }

    func deleteEvent(eventId: String) throws {
    }

    func observeStoreChanges(_ handler: @escaping () -> Void) -> AnyObject {
        NSObject()
    }
}
