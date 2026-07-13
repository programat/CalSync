//
//  EventFiltersView.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import SwiftUI

struct EventFiltersView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: InterfaceMetrics.sectionSpacing) {
            Label("Отменённые встречи", systemImage: "line.3.horizontal.decrease.circle")
                .font(.subheadline)
                .bold()
            Toggle(
                "Пропускать по статусу «Отменено»",
                isOn: $viewModel.excludeCanceledEventsByStatus
            )
            .help("CalSync проверяет внутренний статус EventKit")
            .accessibilityHint("CalSync пропустит события, которые EventKit пометил как отменённые")
            Toggle(
                "Дополнительно проверять префикс",
                isOn: $viewModel.useCanceledTitlePrefixFilter
            )
            .help("CalSync проверяет начало названия события")
            .accessibilityHint("CalSync проверит начало названия события")
            if viewModel.useCanceledTitlePrefixFilter {
                CanceledTitlePrefixesView()
            }
        }
    }
}
