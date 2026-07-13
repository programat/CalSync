//
//  SyncDiagnosticsStore.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import Foundation

nonisolated protocol SyncDiagnosticsStore: AnyObject {
    var lastAttempt: SyncAttemptSnapshot? { get set }
    var lastSuccessfulSyncAt: Date? { get set }
    func clear()
}
