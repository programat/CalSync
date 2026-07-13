//
//  CalendarPickerTile.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import SwiftUI

struct CalendarPickerTile: View {
    let role: String
    let systemImage: String
    let calendars: [CalendarInfo]
    let writableOnly: Bool
    let statusPresentation: SyncStatePresentation?
    @Binding var selection: String?
    @State private var pendingSelection: String?
    @State private var isSelectionPresented = false

    init(
        role: String,
        systemImage: String,
        calendars: [CalendarInfo],
        writableOnly: Bool,
        statusPresentation: SyncStatePresentation? = nil,
        selection: Binding<String?>
    ) {
        self.role = role
        self.systemImage = systemImage
        self.calendars = calendars
        self.writableOnly = writableOnly
        self.statusPresentation = statusPresentation
        _selection = selection
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InterfaceMetrics.controlSpacing) {
            HStack(spacing: InterfaceMetrics.controlSpacing) {
                Label(role, systemImage: systemImage)
                    .font(.subheadline)
                    .bold()
                    .lineLimit(1)
                Spacer(minLength: InterfaceMetrics.controlSpacing)
                if let statusPresentation {
                    SyncStateBadge(presentation: statusPresentation)
                }
            }

            Button(action: presentSelection) {
                HStack(spacing: InterfaceMetrics.controlSpacing) {
                    Text(selectedTitle)
                        .foregroundStyle(selection == nil ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer(minLength: InterfaceMetrics.controlSpacing)
                    Text(selection == nil ? "Выбрать" : "Изменить")
                        .foregroundStyle(.tint)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(role): \(selectedTitle)")
            .accessibilityHint("Открывает выбор календаря")
            .popover(
                isPresented: $isSelectionPresented,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .top
            ) {
                CalendarSelectionPopover(
                    role: role,
                    calendars: calendars,
                    writableOnly: writableOnly,
                    selection: $pendingSelection,
                    onCancel: dismissSelection,
                    onConfirm: confirmSelection
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var selectedTitle: String {
        guard
            let selection,
            let calendar = calendars.first(where: { $0.id == selection })
        else {
            return "Не выбран"
        }
        return calendar.displayTitle
    }

    private func presentSelection() {
        pendingSelection = selection
        isSelectionPresented = true
    }

    private func dismissSelection() {
        isSelectionPresented = false
    }

    private func confirmSelection() {
        selection = pendingSelection
        isSelectionPresented = false
    }

}
