//
//  MainWindowView.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private let sourceOptions = ["Personal", "Work", "Family"]
    private let childOptions = ["Mirror", "Archive", "Shared"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                calendarsSection
                syncWindowSection
                statusSection
                actionsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .frame(minWidth: 520, minHeight: 520)
    }

    private var calendarsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendars")
                .font(.headline)
            Picker("Source Calendar", selection: $viewModel.sourceCalendarId) {
                Text("Not selected").tag(String?.none)
                ForEach(sourceOptions, id: \.self) { option in
                    Text(option).tag(String?.some(option))
                }
            }
            Picker("Child Calendar", selection: $viewModel.childCalendarId) {
                Text("Not selected").tag(String?.none)
                ForEach(childOptions, id: \.self) { option in
                    Text(option).tag(String?.some(option))
                }
            }
        }
    }

    private var syncWindowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync window")
                .font(.headline)
            HStack(spacing: 16) {
                Stepper(value: $viewModel.daysBack, in: 0...365) {
                    HStack {
                        Text("Days back")
                        TextField("", value: $viewModel.daysBack, format: .number)
                            .frame(width: 60)
                    }
                }
                Stepper(value: $viewModel.daysForward, in: 0...365) {
                    HStack {
                        Text("Days forward")
                        TextField("", value: $viewModel.daysForward, format: .number)
                            .frame(width: 60)
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)
            HStack(spacing: 16) {
                Text("Status: \(statusText(viewModel.status))")
                Text("Last sync: \(formattedDate(viewModel.lastSyncAt))")
            }
            HStack(spacing: 16) {
                Text("Created: \(viewModel.createdCount)")
                Text("Updated: \(viewModel.updatedCount)")
                Text("Deleted: \(viewModel.deletedCount)")
            }
            if viewModel.errors.isEmpty {
                Text("No errors")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Errors")
                        .font(.subheadline)
                    ForEach(Array(viewModel.errors.enumerated()), id: \.offset) { _, error in
                        Text(error)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
            HStack(spacing: 12) {
                Button("Sync now") {
                    viewModel.placeholderSync()
                }
                Button("Reset sync") {
                    viewModel.placeholderReset()
                }
            }
        }
    }

    private func statusText(_ status: AppViewModel.Status) -> String {
        switch status {
        case .idle:
            return "Idle"
        case .syncing:
            return "Syncing"
        case .error(let message):
            return message.map { "Error (\($0))" } ?? "Error"
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .standard)
    }
}

#Preview {
    MainWindowView()
        .environmentObject(AppViewModel())
}
