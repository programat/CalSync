//
//  SyncRunText.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import Foundation

nonisolated enum SyncRunText {
    static func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Нет данных" }
        return date.formatted(date: .abbreviated, time: .standard)
    }

    static func outcomeTitle(_ outcome: SyncAttemptSnapshot.Outcome?) -> String {
        switch outcome {
        case .running:
            return "Выполняется"
        case .succeeded:
            return "Успешно"
        case .failed:
            return "Ошибка"
        case nil:
            return "Не запускалась"
        }
    }

    static func outcomeSystemImage(_ outcome: SyncAttemptSnapshot.Outcome?) -> String {
        switch outcome {
        case .running:
            return "clock"
        case .succeeded:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        case nil:
            return "circle.dashed"
        }
    }

    static func reasonsText(_ reasons: Set<SyncReason>) -> String {
        let orderedReasons: [SyncReason] = [
            .manual,
            .appLaunch,
            .autoSyncEnabled,
            .eventStoreChanged,
            .fallbackTimer,
            .settingsChanged,
        ]
        let titles = orderedReasons.compactMap { reason in
            reasons.contains(reason) ? reasonTitle(reason) : nil
        }
        return titles.isEmpty ? "Не указана" : titles.joined(separator: ", ")
    }

    private static func reasonTitle(_ reason: SyncReason) -> String {
        switch reason {
        case .manual:
            return "Вручную"
        case .eventStoreChanged:
            return "Изменение календаря"
        case .fallbackTimer:
            return "Проверка по таймеру"
        case .settingsChanged:
            return "Изменение настроек"
        case .appLaunch:
            return "Запуск CalSync"
        case .autoSyncEnabled:
            return "Включение автосинхронизации"
        }
    }
}
