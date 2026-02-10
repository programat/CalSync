//
//  FakeEventKitGateway.swift
//  CalSyncTests
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import Foundation
@testable import CalSync

struct CreateEventCall {
    let calendarId: String
    let payload: EventInfo
}

struct UpdateEventCall {
    let eventId: String
    let payload: EventInfo
}

final class FakeEventKitGateway: EventKitGateway {
    var requestAccessError: Error?
    var calendarsToReturn: [CalendarInfo] = []
    var fetchCalendarsError: Error?
    var fetchEventsToReturn: [EventInfo] = []
    var fetchEventsError: Error?
    var getEventError: Error?
    var createEventError: Error?
    var updateEventError: Error?
    var deleteEventError: Error?
    var eventsById: [String: EventInfo] = [:]

    private(set) var fetchEventsCallCount = 0
    private(set) var getEventCallCount = 0
    private(set) var createEventCallCount = 0
    private(set) var updateEventCallCount = 0
    private(set) var deleteEventCallCount = 0
    private(set) var createEventCalls: [CreateEventCall] = []
    private(set) var updateEventCalls: [UpdateEventCall] = []
    private(set) var deletedEventIds: [String] = []
    private var storeChangeHandler: (() -> Void)?

    func configureRecurringScenario(
        seriesEventId: String = "series-event-id",
        seriesCalendarItemId: String = "series-calendar-item-id",
        startDate: Date = Date(timeIntervalSince1970: 1_737_000_000),
        includeOccurrenceDate: Bool = true,
        isRecurringFlag: Bool = true
    ) {
        fetchEventsToReturn = Self.makeRecurringOccurrences(
            seriesEventId: seriesEventId,
            seriesCalendarItemId: seriesCalendarItemId,
            startDate: startDate,
            includeOccurrenceDate: includeOccurrenceDate,
            isRecurringFlag: isRecurringFlag
        )
    }

    func requestAccess() async throws {
        if let requestAccessError {
            throw requestAccessError
        }
    }

    func fetchCalendars() throws -> [CalendarInfo] {
        if let fetchCalendarsError {
            throw fetchCalendarsError
        }
        return calendarsToReturn
    }

    func fetchEvents(calendarId: String, from: Date, to: Date) throws -> [EventInfo] {
        fetchEventsCallCount += 1
        if let fetchEventsError {
            throw fetchEventsError
        }
        return fetchEventsToReturn
    }

    func getEvent(byId: String) throws -> EventInfo? {
        getEventCallCount += 1
        if let getEventError {
            throw getEventError
        }
        return eventsById[byId]
    }

    func createEvent(in calendarId: String, payload: EventInfo) throws -> String {
        createEventCallCount += 1
        if let createEventError {
            throw createEventError
        }

        createEventCalls.append(CreateEventCall(calendarId: calendarId, payload: payload))
        let eventId = "child-event-\(createEventCallCount)"
        eventsById[eventId] = payload
        return eventId
    }

    func updateEvent(eventId: String, payload: EventInfo) throws {
        updateEventCallCount += 1
        if let updateEventError {
            throw updateEventError
        }

        updateEventCalls.append(UpdateEventCall(eventId: eventId, payload: payload))
        eventsById[eventId] = payload
    }

    func deleteEvent(eventId: String) throws {
        deleteEventCallCount += 1
        if let deleteEventError {
            throw deleteEventError
        }
        deletedEventIds.append(eventId)
        eventsById[eventId] = nil
    }

    func observeStoreChanges(_ handler: @escaping () -> Void) -> AnyObject {
        storeChangeHandler = handler
        return NSObject()
    }

    func triggerStoreChange() {
        storeChangeHandler?()
    }

    private static func makeRecurringOccurrences(
        seriesEventId: String,
        seriesCalendarItemId: String,
        startDate: Date,
        includeOccurrenceDate: Bool,
        isRecurringFlag: Bool
    ) -> [EventInfo] {
        let day: TimeInterval = 24 * 60 * 60
        return (0..<3).map { index in
            let occurrenceDate = startDate.addingTimeInterval(day * Double(index))
            return EventInfo(
                eventId: seriesEventId,
                calendarItemId: seriesCalendarItemId,
                occurrenceDate: includeOccurrenceDate ? occurrenceDate : nil,
                isRecurring: isRecurringFlag,
                title: "Recurring \(index + 1)",
                notes: "Occurrence \(index + 1)",
                location: "Room \(index + 1)",
                structuredLocation: nil,
                startDate: occurrenceDate,
                endDate: occurrenceDate.addingTimeInterval(3600),
                isAllDay: false,
                timeZone: TimeZone(secondsFromGMT: 0),
                availability: .busy,
                status: .confirmed,
                alarms: [],
                url: URL(string: "https://example.com/recurring/\(index + 1)")
            )
        }
    }
}
