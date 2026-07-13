//
//  CalendarSettingsView.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import SwiftUI

struct CalendarSettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: InterfaceMetrics.sectionSpacing) {
                SettingsCard {
                    CalendarPickerTile(
                        role: "Source",
                        systemImage: "calendar",
                        calendars: viewModel.calendars,
                        writableOnly: false,
                        selection: $viewModel.sourceCalendarId
                    )
                }
                .frame(minWidth: 240, maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                SettingsCard {
                    CalendarPickerTile(
                        role: "Child",
                        systemImage: "calendar.badge.plus",
                        calendars: viewModel.calendars,
                        writableOnly: true,
                        statusPresentation: statusPresentation,
                        selection: $viewModel.childCalendarId
                    )
                }
                .frame(minWidth: 240, maxWidth: .infinity)
            }

            VStack(spacing: InterfaceMetrics.controlSpacing) {
                SettingsCard {
                    CalendarPickerTile(
                        role: "Source",
                        systemImage: "calendar",
                        calendars: viewModel.calendars,
                        writableOnly: false,
                        selection: $viewModel.sourceCalendarId
                    )
                }

                Image(systemName: "arrow.down")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                SettingsCard {
                    CalendarPickerTile(
                        role: "Child",
                        systemImage: "calendar.badge.plus",
                        calendars: viewModel.calendars,
                        writableOnly: true,
                        statusPresentation: statusPresentation,
                        selection: $viewModel.childCalendarId
                    )
                }
            }
        }
    }

    private var statusPresentation: SyncStatePresentation? {
        if
            viewModel.childCalendarId == nil,
            viewModel.lastSyncOutcome == nil,
            viewModel.status == .idle
        {
            return nil
        }
        return SyncStatePresentation(
            status: viewModel.status,
            lastOutcome: viewModel.lastSyncOutcome
        )
    }
}
