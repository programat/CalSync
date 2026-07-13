//
//  SyncActionBar.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import SwiftUI

struct SyncActionBar: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var isResetConfirmationPresented = false

    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            Button(role: .destructive, action: presentResetConfirmation) {
                Label("Сбросить", systemImage: "trash")
            }
            .help("Удалить события, которые создал CalSync")
            .disabled(viewModel.status == .syncing)
            Button("Синхронизировать", systemImage: "arrow.triangle.2.circlepath", action: viewModel.syncNow)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(viewModel.status == .syncing)
        }
        .padding(.horizontal, InterfaceMetrics.cardPadding)
        .padding(.vertical, 10)
        .background(.bar)
        .confirmationDialog(
            "Удалить созданные CalSync копии?",
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Удалить копии", role: .destructive, action: viewModel.resetSync)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("CalSync удалит копии из Child. События в Source останутся.")
        }
    }

    private func presentResetConfirmation() {
        isResetConfirmationPresented = true
    }
}
