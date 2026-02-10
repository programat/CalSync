//
//  EventKitGatewayImpl.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import CoreLocation
import EventKit
import Foundation

final class EventKitGatewayImpl: EventKitGateway {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    func requestAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess {
            return
        }

        let granted = try await eventStore.requestFullAccessToEvents()
        guard granted else {
            throw EventKitGatewayError.accessDenied
        }
    }

    func fetchCalendars() throws -> [CalendarInfo] {
        try ensureAccessGranted()
        return eventStore.calendars(for: .event).map { calendar in
            CalendarInfo(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                sourceTitle: calendar.source.title,
                isWritable: calendar.allowsContentModifications
            )
        }
    }

    func fetchEvents(calendarId: String, from: Date, to: Date) throws -> [EventInfo] {
        try ensureAccessGranted()
        guard let calendar = eventStore.calendar(withIdentifier: calendarId) else {
            throw EventKitGatewayError.calendarNotFound
        }

        let predicate = eventStore.predicateForEvents(withStart: from, end: to, calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        return events.map { makeEventInfo(from: $0) }
    }

    func getEvent(byId: String) throws -> EventInfo? {
        try ensureAccessGranted()
        guard let event = eventStore.event(withIdentifier: byId) else {
            return nil
        }
        return makeEventInfo(from: event)
    }

    func createEvent(in calendarId: String, payload: EventInfo) throws -> String {
        try ensureAccessGranted()
        guard let calendar = eventStore.calendar(withIdentifier: calendarId) else {
            throw EventKitGatewayError.calendarNotFound
        }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        apply(payload, to: event)

        try eventStore.save(event, span: .thisEvent, commit: true)

        guard let identifier = event.eventIdentifier else {
            throw EventKitGatewayError.missingEventIdentifier
        }

        return identifier
    }

    func updateEvent(eventId: String, payload: EventInfo) throws {
        try ensureAccessGranted()
        guard let event = eventStore.event(withIdentifier: eventId) else {
            throw EventKitGatewayError.eventNotFound
        }

        apply(payload, to: event)
        try eventStore.save(event, span: .thisEvent, commit: true)
    }

    func deleteEvent(eventId: String) throws {
        try ensureAccessGranted()
        guard let event = eventStore.event(withIdentifier: eventId) else {
            return
        }
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }

    func observeStoreChanges(_ handler: @escaping () -> Void) -> AnyObject {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { _ in
            handler()
        }
    }
}

private extension EventKitGatewayImpl {
    func ensureAccessGranted() throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status != .fullAccess {
            throw EventKitGatewayError.accessDenied
        }
    }

    func makeEventInfo(from event: EKEvent) -> EventInfo {
        EventInfo(
            eventId: event.eventIdentifier,
            calendarItemId: event.calendarItemIdentifier,
            occurrenceDate: event.occurrenceDate,
            isRecurring: event.hasRecurrenceRules || event.occurrenceDate != nil,
            title: event.title ?? "",
            notes: event.notes,
            location: event.location,
            structuredLocation: event.structuredLocation.map { makeStructuredLocationInfo(from: $0) },
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            timeZone: event.timeZone,
            availability: makeAvailability(from: event.availability),
            status: makeStatus(from: event.status),
            // Alarm mirroring is disabled to avoid sandbox warnings for unsupported alarm types.
            alarms: [],
            url: event.url
        )
    }

    func apply(_ payload: EventInfo, to event: EKEvent) {
        event.title = payload.title
        event.notes = payload.notes
        event.location = payload.location
        event.structuredLocation = payload.structuredLocation.map { makeStructuredLocation(from: $0) }
        event.startDate = payload.startDate
        event.endDate = payload.endDate
        event.isAllDay = payload.isAllDay
        event.timeZone = payload.timeZone
        event.availability = makeAvailability(from: payload.availability)
        event.alarms = nil
        event.url = payload.url
        event.recurrenceRules = nil
    }

    func makeStructuredLocationInfo(from location: EKStructuredLocation) -> StructuredLocationInfo {
        StructuredLocationInfo(
            title: location.title ?? "",
            latitude: location.geoLocation?.coordinate.latitude,
            longitude: location.geoLocation?.coordinate.longitude,
            radius: location.radius == 0 ? nil : location.radius
        )
    }

    func makeStructuredLocation(from info: StructuredLocationInfo) -> EKStructuredLocation {
        let location = EKStructuredLocation(title: info.title)
        if let latitude = info.latitude, let longitude = info.longitude {
            location.geoLocation = CLLocation(latitude: latitude, longitude: longitude)
        }
        if let radius = info.radius {
            location.radius = radius
        }
        return location
    }

    func makeAvailability(from availability: EKEventAvailability) -> EventAvailability {
        switch availability {
        case .notSupported:
            return .notSupported
        case .busy:
            return .busy
        case .free:
            return .free
        case .tentative:
            return .tentative
        case .unavailable:
            return .unavailable
        @unknown default:
            return .notSupported
        }
    }

    func makeAvailability(from availability: EventAvailability) -> EKEventAvailability {
        switch availability {
        case .busy:
            return .busy
        case .free:
            return .free
        case .tentative:
            return .tentative
        case .unavailable:
            return .unavailable
        case .notSupported:
            return .notSupported
        }
    }

    func makeStatus(from status: EKEventStatus) -> EventStatus {
        switch status {
        case .none:
            return .none
        case .confirmed:
            return .confirmed
        case .tentative:
            return .tentative
        case .canceled:
            return .canceled
        @unknown default:
            return .none
        }
    }

    func makeStatus(from status: EventStatus) -> EKEventStatus {
        switch status {
        case .confirmed:
            return .confirmed
        case .tentative:
            return .tentative
        case .canceled:
            return .canceled
        case .none:
            return .none
        }
    }

    func makeAlarmProximity(from proximity: EKAlarmProximity) -> AlarmProximity {
        switch proximity {
        case .none:
            return .none
        case .enter:
            return .enter
        case .leave:
            return .leave
        @unknown default:
            return .none
        }
    }

    func makeAlarmProximity(from proximity: AlarmProximity) -> EKAlarmProximity {
        switch proximity {
        case .enter:
            return .enter
        case .leave:
            return .leave
        case .none:
            return .none
        }
    }
}
