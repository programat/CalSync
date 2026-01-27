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
    @Published var daysBack: Int
    @Published var daysForward: Int
    @Published var status: Status
    @Published var lastSyncAt: Date?
    @Published var createdCount: Int
    @Published var updatedCount: Int
    @Published var deletedCount: Int
    @Published var errors: [String]

    init(
        sourceCalendarId: String? = nil,
        childCalendarId: String? = nil,
        daysBack: Int = 30,
        daysForward: Int = 90,
        status: Status = .idle,
        lastSyncAt: Date? = nil,
        createdCount: Int = 0,
        updatedCount: Int = 0,
        deletedCount: Int = 0,
        errors: [String] = []
    ) {
        self.sourceCalendarId = sourceCalendarId
        self.childCalendarId = childCalendarId
        self.daysBack = daysBack
        self.daysForward = daysForward
        self.status = status
        self.lastSyncAt = lastSyncAt
        self.createdCount = createdCount
        self.updatedCount = updatedCount
        self.deletedCount = deletedCount
        self.errors = errors
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
}
