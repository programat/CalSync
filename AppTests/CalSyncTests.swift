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

}
