//
//  StatusBarPresentation.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import Foundation

nonisolated struct StatusBarPresentation: Equatable, Sendable {
    let symbolName: String
    let toolTip: String
    let accessibilityValue: String
    let isError: Bool

    init(status: AppViewModel.Status) {
        switch status {
        case .idle:
            symbolName = "calendar"
            toolTip = "CalSync готов к синхронизации."
            accessibilityValue = "Готов к синхронизации"
            isError = false
        case .syncing:
            symbolName = "calendar.badge.clock"
            toolTip = "CalSync синхронизирует календари."
            accessibilityValue = "Идёт синхронизация"
            isError = false
        case .error:
            symbolName = "calendar.badge.exclamationmark"
            toolTip = "Ошибка синхронизации. Откройте CalSync."
            accessibilityValue = "Ошибка синхронизации"
            isError = true
        }
    }
}
