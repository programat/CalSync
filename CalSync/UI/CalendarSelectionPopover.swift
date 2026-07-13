//
//  CalendarSelectionPopover.swift
//  CalSync
//
//  Created by Codex on 13.07.2026.
//

import SwiftUI

struct CalendarSelectionPopover: View {
    let role: String
    let calendars: [CalendarInfo]
    let writableOnly: Bool
    @Binding var selection: String?
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(role)
                .font(.headline)
                .padding(InterfaceMetrics.innerPadding)

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    CalendarSelectionRow(
                        title: "Не выбран",
                        isSelected: selection == nil,
                        isEnabled: true,
                        action: clearSelection
                    )

                    ForEach(calendars) { calendar in
                        CalendarSelectionRow(
                            title: calendar.displayTitle,
                            detail: writableOnly && !calendar.isWritable ? "Только чтение" : nil,
                            isSelected: selection == calendar.id,
                            isEnabled: !writableOnly || calendar.isWritable,
                            action: { select(calendar) }
                        )
                        .help(
                            writableOnly && !calendar.isWritable
                                ? "Календарь доступен только для чтения"
                                : ""
                        )
                    }
                }
                .padding(8)
            }
            .frame(height: listHeight)

            Divider()

            HStack(spacing: InterfaceMetrics.controlSpacing) {
                Spacer()
                Button("Отмена", action: onCancel)
                Button("Выбрать", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(InterfaceMetrics.innerPadding)
        }
        .frame(width: 360)
    }

    private var listHeight: CGFloat {
        min(max(CGFloat(calendars.count + 1) * 38, 120), 280)
    }

    private func clearSelection() {
        selection = nil
    }

    private func select(_ calendar: CalendarInfo) {
        guard !writableOnly || calendar.isWritable else { return }
        selection = calendar.id
    }

}
