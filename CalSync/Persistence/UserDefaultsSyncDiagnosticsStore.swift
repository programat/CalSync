//
//  UserDefaultsSyncDiagnosticsStore.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import Foundation

nonisolated final class UserDefaultsSyncDiagnosticsStore: SyncDiagnosticsStore {
    private enum Key {
        static let lastAttemptTimestamp = "syncDiagnostics.lastAttemptTimestamp"
        static let lastAttemptReasons = "syncDiagnostics.lastAttemptReasons"
        static let lastAttemptOutcome = "syncDiagnostics.lastAttemptOutcome"
        static let lastAttemptTotalFetched = "syncDiagnostics.lastAttemptTotalFetched"
        static let lastAttemptCreated = "syncDiagnostics.lastAttemptCreated"
        static let lastAttemptUpdated = "syncDiagnostics.lastAttemptUpdated"
        static let lastAttemptDeleted = "syncDiagnostics.lastAttemptDeleted"
        static let lastSuccessfulSyncAt = "syncDiagnostics.lastSuccessfulSyncAt"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var lastAttempt: SyncAttemptSnapshot? {
        get {
            guard
                let timestamp = userDefaults.object(forKey: Key.lastAttemptTimestamp) as? Date,
                let rawOutcome = userDefaults.string(forKey: Key.lastAttemptOutcome),
                let storedOutcome = SyncAttemptSnapshot.Outcome(rawValue: rawOutcome)
            else {
                return nil
            }

            let reasons = Set(
                userDefaults.stringArray(forKey: Key.lastAttemptReasons)?
                    .compactMap(SyncReason.init(rawValue:)) ?? []
            )
            let outcome: SyncAttemptSnapshot.Outcome = storedOutcome == .running ? .failed : storedOutcome
            return SyncAttemptSnapshot(
                timestamp: timestamp,
                reasons: reasons,
                outcome: outcome,
                metrics: storedMetrics()
            )
        }
        set {
            guard let newValue else {
                userDefaults.removeObject(forKey: Key.lastAttemptTimestamp)
                userDefaults.removeObject(forKey: Key.lastAttemptReasons)
                userDefaults.removeObject(forKey: Key.lastAttemptOutcome)
                clearStoredMetrics()
                return
            }
            userDefaults.set(newValue.timestamp, forKey: Key.lastAttemptTimestamp)
            userDefaults.set(
                newValue.reasons.map(\.rawValue).sorted(),
                forKey: Key.lastAttemptReasons
            )
            userDefaults.set(newValue.outcome.rawValue, forKey: Key.lastAttemptOutcome)
            if let metrics = newValue.metrics {
                userDefaults.set(metrics.totalFetched, forKey: Key.lastAttemptTotalFetched)
                userDefaults.set(metrics.created, forKey: Key.lastAttemptCreated)
                userDefaults.set(metrics.updated, forKey: Key.lastAttemptUpdated)
                userDefaults.set(metrics.deleted, forKey: Key.lastAttemptDeleted)
            } else {
                clearStoredMetrics()
            }
        }
    }

    var lastSuccessfulSyncAt: Date? {
        get { userDefaults.object(forKey: Key.lastSuccessfulSyncAt) as? Date }
        set {
            guard let newValue else {
                userDefaults.removeObject(forKey: Key.lastSuccessfulSyncAt)
                return
            }
            userDefaults.set(newValue, forKey: Key.lastSuccessfulSyncAt)
        }
    }

    func clear() {
        lastAttempt = nil
        lastSuccessfulSyncAt = nil
    }

    private func storedMetrics() -> SyncAttemptSnapshot.Metrics? {
        let keys = [
            Key.lastAttemptTotalFetched,
            Key.lastAttemptCreated,
            Key.lastAttemptUpdated,
            Key.lastAttemptDeleted,
        ]
        guard keys.allSatisfy({ userDefaults.object(forKey: $0) != nil }) else {
            return nil
        }
        return SyncAttemptSnapshot.Metrics(
            totalFetched: userDefaults.integer(forKey: Key.lastAttemptTotalFetched),
            created: userDefaults.integer(forKey: Key.lastAttemptCreated),
            updated: userDefaults.integer(forKey: Key.lastAttemptUpdated),
            deleted: userDefaults.integer(forKey: Key.lastAttemptDeleted)
        )
    }

    private func clearStoredMetrics() {
        userDefaults.removeObject(forKey: Key.lastAttemptTotalFetched)
        userDefaults.removeObject(forKey: Key.lastAttemptCreated)
        userDefaults.removeObject(forKey: Key.lastAttemptUpdated)
        userDefaults.removeObject(forKey: Key.lastAttemptDeleted)
    }
}
