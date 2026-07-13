//
//  SyncStatePresentation.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

nonisolated struct SyncStatePresentation: Equatable, Sendable {
    enum Tone: Equatable, Sendable {
        case neutral
        case active
        case success
        case error
    }

    let title: String
    let systemImage: String
    let tone: Tone

    init(status: AppViewModel.Status, lastOutcome: SyncAttemptSnapshot.Outcome?) {
        switch status {
        case .syncing:
            title = "Синхронизация"
            systemImage = "arrow.triangle.2.circlepath"
            tone = .active
        case .error:
            title = "Ошибка"
            systemImage = "exclamationmark.triangle.fill"
            tone = .error
        case .idle:
            switch lastOutcome {
            case .succeeded:
                title = "Синхронизировано"
                systemImage = "checkmark.circle.fill"
                tone = .success
            case .failed:
                title = "Ошибка"
                systemImage = "exclamationmark.triangle.fill"
                tone = .error
            case .running:
                title = "Синхронизация"
                systemImage = "arrow.triangle.2.circlepath"
                tone = .active
            case nil:
                title = "Готово"
                systemImage = "circle"
                tone = .neutral
            }
        }
    }
}
