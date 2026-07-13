//
//  CanceledTitlePrefixesView.swift
//  CalSync
//
//  Created by Codex on 13.07.2026.
//

import SwiftUI

struct CanceledTitlePrefixesView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var newPrefix = ""

    var body: some View {
        VStack(alignment: .leading, spacing: InterfaceMetrics.controlSpacing) {
            if viewModel.canceledTitlePrefixes.isEmpty {
                Text("Префиксы не заданы")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.canceledTitlePrefixes, id: \.self) { prefix in
                    HStack(spacing: InterfaceMetrics.controlSpacing) {
                        Text(prefix)
                            .lineLimit(1)
                            .help(prefix)
                        Spacer(minLength: InterfaceMetrics.controlSpacing)
                        Button(
                            "Удалить \(prefix)",
                            systemImage: "xmark",
                            action: { removePrefix(prefix) }
                        )
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help("Удалить префикс «\(prefix)»")
                    }
                }
            }

            HStack(spacing: InterfaceMetrics.controlSpacing) {
                TextField("Новый префикс", text: $newPrefix)
                    .onSubmit(addPrefix)
                Button("Добавить", systemImage: "plus", action: addPrefix)
                    .disabled(!canAddPrefix)
            }
        }
        .padding(.leading, InterfaceMetrics.innerPadding)
    }

    private var canAddPrefix: Bool {
        viewModel.canAddCanceledTitlePrefix(newPrefix)
    }

    private func addPrefix() {
        guard viewModel.addCanceledTitlePrefix(newPrefix) else { return }
        newPrefix = ""
    }

    private func removePrefix(_ prefix: String) {
        viewModel.removeCanceledTitlePrefix(prefix)
    }
}
