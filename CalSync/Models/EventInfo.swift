//
//  EventInfo.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import Foundation

nonisolated struct EventInfo: Equatable, Sendable {
    let eventId: String?
    let calendarItemId: String?
    let occurrenceDate: Date?
    let isRecurring: Bool
    let title: String
    let notes: String?
    let location: String?
    let structuredLocation: StructuredLocationInfo?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let timeZone: TimeZone?
    let availability: EventAvailability
    let status: EventStatus
    let alarms: [AlarmInfo]
    let url: URL?

    nonisolated init(
        eventId: String?,
        calendarItemId: String?,
        occurrenceDate: Date?,
        isRecurring: Bool = false,
        title: String,
        notes: String?,
        location: String?,
        structuredLocation: StructuredLocationInfo?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        timeZone: TimeZone?,
        availability: EventAvailability,
        status: EventStatus,
        alarms: [AlarmInfo],
        url: URL?
    ) {
        self.eventId = eventId
        self.calendarItemId = calendarItemId
        self.occurrenceDate = occurrenceDate
        self.isRecurring = isRecurring
        self.title = title
        self.notes = notes
        self.location = location
        self.structuredLocation = structuredLocation
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.timeZone = timeZone
        self.availability = availability
        self.status = status
        self.alarms = alarms
        self.url = url
    }
}

nonisolated struct StructuredLocationInfo: Equatable, Sendable {
    let title: String
    let latitude: Double?
    let longitude: Double?
    let radius: Double?
}

nonisolated struct AlarmInfo: Equatable, Sendable {
    let absoluteDate: Date?
    let relativeOffset: TimeInterval?
    let structuredLocation: StructuredLocationInfo?
    let proximity: AlarmProximity
}

nonisolated enum EventAvailability: String, Equatable, Sendable {
    case notSupported
    case busy
    case free
    case tentative
    case unavailable
}

nonisolated enum EventStatus: String, Equatable, Sendable {
    case none
    case confirmed
    case tentative
    case canceled
}

nonisolated enum AlarmProximity: String, Equatable, Sendable {
    case none
    case enter
    case leave
}
