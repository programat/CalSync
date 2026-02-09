//
//  CalSyncTests.swift
//  CalSyncTests
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

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
        #expect(await viewModel.sourceCalendars.count == 2)
        #expect(await viewModel.childCalendars.map(\.id) == ["child-id"])
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
        #expect(await viewModel.sourceCalendars.isEmpty)
    }

}
