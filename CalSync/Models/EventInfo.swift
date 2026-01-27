//
//  EventInfo.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import Foundation

struct EventInfo: Equatable {
    let eventId: String?
    let calendarItemId: String?
    let occurrenceDate: Date?
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
}

struct StructuredLocationInfo: Equatable {
    let title: String
    let latitude: Double?
    let longitude: Double?
    let radius: Double?
}

struct AlarmInfo: Equatable {
    let absoluteDate: Date?
    let relativeOffset: TimeInterval?
    let structuredLocation: StructuredLocationInfo?
    let proximity: AlarmProximity
}

enum EventAvailability: Equatable {
    case notSupported
    case busy
    case free
    case tentative
    case unavailable
}

enum EventStatus: Equatable {
    case none
    case confirmed
    case tentative
    case canceled
}

enum AlarmProximity: Equatable {
    case none
    case enter
    case leave
}
