//
//  SyncSettingsView.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import SwiftUI

struct SyncSettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: InterfaceMetrics.sectionSpacing) {
            HStack(spacing: InterfaceMetrics.controlSpacing) {
                Label("Автосинхронизация", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                    .bold()
                Spacer()
                Toggle("Автосинхронизация", isOn: $viewModel.isAutoSyncEnabled)
                    .labelsHidden()
            }
            .help("CalSync реагирует на изменения календаря и выполняет проверку по таймеру")
            .accessibilityHint("Ручная синхронизация работает при выключенной настройке")

            NumberStepperField(
                title: "Проверять каждые",
                value: $viewModel.autoSyncIntervalMinutes,
                range: UserDefaultsSettingsStore.autoSyncIntervalMinutesRange,
                unit: "мин"
            )
            .help("CalSync реагирует на изменения календаря и выполняет проверку по таймеру")
            .disabled(!viewModel.isAutoSyncEnabled)

            Divider()

            Label("Диапазон событий", systemImage: "calendar.badge.clock")
                .font(.subheadline)
                .bold()

            NumberStepperField(
                title: "Назад",
                value: $viewModel.daysBack,
                range: 0...365,
                unit: "дн."
            )
            NumberStepperField(
                title: "Вперёд",
                value: $viewModel.daysForward,
                range: 0...365,
                unit: "дн."
            )
        }
    }
}
