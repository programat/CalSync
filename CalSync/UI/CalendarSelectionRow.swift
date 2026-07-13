//
//  CalendarSelectionRow.swift
//  CalSync
//
//  Created by Codex on 13.07.2026.
//

import SwiftUI

struct CalendarSelectionRow: View {
    let title: String
    var detail: String?
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: InterfaceMetrics.controlSpacing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .lineLimit(1)
                Spacer(minLength: InterfaceMetrics.controlSpacing)
                if let detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                isSelected ? Color.accentColor.opacity(0.1) : Color.clear,
                in: RoundedRectangle(cornerRadius: InterfaceMetrics.innerRadius)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        [isSelected ? "Выбран" : nil, detail]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
