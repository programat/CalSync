//
//  CalSyncTests.swift
//  CalSyncTests
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import Foundation
import Testing
@testable import CalSync

struct CalSyncTests {

    @Test func placeholderSyncUpdatesState() async throws {
        let viewModel = await AppViewModel()
        let initialErrors = await viewModel.errors.count
        let initialCreated = await viewModel.createdCount

        await viewModel.placeholderSync()

        let status = await viewModel.status
        #expect(status == .idle)
        #expect(await viewModel.lastSyncAt != nil)
        #expect(await viewModel.createdCount == initialCreated + 1)
        #expect(await viewModel.errors.count == initialErrors + 1)
    }

    @Test func placeholderResetClearsCounts() async throws {
        let viewModel = await AppViewModel()
        await viewModel.placeholderSync()
        await viewModel.placeholderSync()

        let initialErrors = await viewModel.errors.count
        await viewModel.placeholderReset()

        let status = await viewModel.status
        #expect(status == .idle)
        #expect(await viewModel.createdCount == 0)
        #expect(await viewModel.updatedCount == 0)
        #expect(await viewModel.deletedCount == 0)
        #expect(await viewModel.errors.count == initialErrors + 1)
    }

    @Test func onAppStartRequestsAccessAndLoadsCalendars() async throws {
        let gateway = FakeEventKitGateway()
        gateway.calendarsToReturn = [
            CalendarInfo(id: "source-id", title: "Source", sourceTitle: "iCloud", isWritable: false),
            CalendarInfo(id: "child-id", title: "Child", sourceTitle: "iCloud", isWritable: true),
        ]
        let viewModel = await AppViewModel(eventKitGateway: gateway)

        await viewModel.onAppStart()

        #expect(await viewModel.status == .idle)
        #expect(await viewModel.calendars.count == 2)
    }

    @Test func requestCalendarAccessSetsErrorOnDeniedAccess() async throws {
        let gateway = FakeEventKitGateway()
        gateway.requestAccessError = EventKitGatewayError.accessDenied
        let viewModel = await AppViewModel(eventKitGateway: gateway)

        await viewModel.requestCalendarAccess()

        let status = await viewModel.status
        if case .error(let message) = status {
            #expect(message?.contains("Нет доступа к календарям") == true)
        } else {
            #expect(Bool(false))
        }
        #expect(await viewModel.errors.count == 1)
        #expect(await viewModel.calendars.isEmpty)
    }

    @Test func selectingSameSourceAndChildClearsChildAndAddsError() async throws {
        let viewModel = await AppViewModel()
        await MainActor.run {
            viewModel.calendars = [
                CalendarInfo(id: "calendar-id", title: "Main", sourceTitle: nil, isWritable: true),
            ]
            viewModel.sourceCalendarId = "calendar-id"
            viewModel.childCalendarId = "calendar-id"
        }

        #expect(await viewModel.sourceCalendarId == "calendar-id")
        #expect(await viewModel.childCalendarId == nil)
        #expect(await viewModel.errors.last == "Source и Child не могут быть одинаковыми.")
    }

    @Test func appViewModelInitReadsSettingsFromStore() async throws {
        let (store, userDefaults, suiteName) = makeSettingsStore()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        store.sourceCalendarId = "stored-source"
        store.childCalendarId = "stored-child"
        store.daysBack = 7
        store.daysForward = 21

        let viewModel = await AppViewModel(
            eventKitGateway: FakeEventKitGateway(),
            settingsStore: store
        )

        #expect(await viewModel.sourceCalendarId == "stored-source")
        #expect(await viewModel.childCalendarId == "stored-child")
        #expect(await viewModel.daysBack == 7)
        #expect(await viewModel.daysForward == 21)
    }

    @Test func appViewModelPersistsAndRestoresSettings() async throws {
        let (store, userDefaults, suiteName) = makeSettingsStore()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let firstViewModel = await AppViewModel(
            eventKitGateway: FakeEventKitGateway(),
            settingsStore: store
        )

        await MainActor.run {
            firstViewModel.calendars = [
                CalendarInfo(id: "source-id", title: "Source", sourceTitle: "iCloud", isWritable: true),
                CalendarInfo(id: "child-id", title: "Child", sourceTitle: "iCloud", isWritable: true),
            ]
            firstViewModel.sourceCalendarId = "source-id"
            firstViewModel.childCalendarId = "child-id"
            firstViewModel.daysBack = 3
            firstViewModel.daysForward = 45
        }

        let secondViewModel = await AppViewModel(
            eventKitGateway: FakeEventKitGateway(),
            settingsStore: store
        )

        #expect(await secondViewModel.sourceCalendarId == "source-id")
        #expect(await secondViewModel.childCalendarId == "child-id")
        #expect(await secondViewModel.daysBack == 3)
        #expect(await secondViewModel.daysForward == 45)
    }

}

private func makeSettingsStore() -> (UserDefaultsSettingsStore, UserDefaults, String) {
    let suiteName = "CalSyncTests.Settings.\(UUID().uuidString)"
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
        fatalError("Failed to create UserDefaults suite \(suiteName)")
    }
    userDefaults.removePersistentDomain(forName: suiteName)
    let store = UserDefaultsSettingsStore(userDefaults: userDefaults)
    return (store, userDefaults, suiteName)
}
