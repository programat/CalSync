//
//  SyncStatusView.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import SwiftUI

struct SyncStatusView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        SettingsCard {
            HStack(alignment: .firstTextBaseline) {
                Label("Последняя попытка", systemImage: "clock")
                    .font(.headline)
                Spacer()
                Label(
                    SyncRunText.outcomeTitle(viewModel.lastSyncOutcome),
                    systemImage: SyncRunText.outcomeSystemImage(viewModel.lastSyncOutcome)
                )
                .font(.subheadline)
                .bold()
                .foregroundStyle(outcomeColor)
            }
            if let statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            HStack(alignment: .firstTextBaseline) {
                if !viewModel.lastSyncReasons.isEmpty {
                    Text(SyncRunText.reasonsText(viewModel.lastSyncReasons))
                }
                Spacer()
                Text(SyncRunText.formattedDate(viewModel.lastSyncAttemptAt))
                    .monospacedDigit()
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            if viewModel.lastSyncOutcome != .succeeded, viewModel.lastSuccessfulSyncAt != nil {
                LabeledContent("Последний успех") {
                    Text(SyncRunText.formattedDate(viewModel.lastSuccessfulSyncAt))
                        .monospacedDigit()
                }
            }
            if viewModel.lastSyncOutcome == .succeeded {
                Divider()
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 4) {
                    GridRow {
                        Text("Найдено")
                        Text("Создано")
                        Text("Обновлено")
                        Text("Удалено")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    GridRow {
                        Text(viewModel.totalFetchedCount, format: .number)
                        Text(viewModel.createdCount, format: .number)
                        Text(viewModel.updatedCount, format: .number)
                        Text(viewModel.deletedCount, format: .number)
                    }
                    .font(.body)
                    .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isErrorStatus {
                Divider()
                HStack(alignment: .center, spacing: 12) {
                    Label("Проверьте доступ CalSync к календарям", systemImage: "lock.trianglebadge.exclamationmark")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Запросить доступ", action: requestCalendarAccess)
                }
            }
            if !viewModel.errors.isEmpty {
                Divider()
                DisclosureGroup("Журнал ошибок (\(viewModel.errors.count))") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(viewModel.errors.suffix(5).enumerated()), id: \.offset) { _, error in
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var statusMessage: String? {
        guard case .error(let message) = viewModel.status else { return nil }
        return message
    }

    private var isErrorStatus: Bool {
        if case .error = viewModel.status {
            return true
        }
        return false
    }

    private var outcomeColor: Color {
        switch viewModel.lastSyncOutcome {
        case .running:
            return .accentColor
        case .succeeded:
            return .green
        case .failed:
            return .red
        case nil:
            return .secondary
        }
    }

    private func requestCalendarAccess() {
        Task {
            await viewModel.requestCalendarAccess()
        }
    }
}
