//
//  SyncAttemptSnapshot.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import Foundation

nonisolated struct SyncAttemptSnapshot: Equatable, Sendable {
    enum Outcome: String, Equatable, Sendable {
        case running
        case succeeded
        case failed
    }

    struct Metrics: Equatable, Sendable {
        let totalFetched: Int
        let created: Int
        let updated: Int
        let deleted: Int
    }

    let timestamp: Date
    let reasons: Set<SyncReason>
    let outcome: Outcome
    let metrics: Metrics?

    init(
        timestamp: Date,
        reasons: Set<SyncReason>,
        outcome: Outcome,
        metrics: Metrics? = nil
    ) {
        self.timestamp = timestamp
        self.reasons = reasons
        self.outcome = outcome
        self.metrics = metrics
    }
}
