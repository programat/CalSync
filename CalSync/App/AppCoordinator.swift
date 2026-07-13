//
//  AppCoordinator.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import AppKit

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let windowCoordinator = WindowCoordinator()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(
            appCoordinator: self,
            statusPublisher: windowCoordinator.statusPublisher
        )
        Task {
            await windowCoordinator.onAppStart()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        windowCoordinator.showMainWindow()
    }

    func syncNowFromStatusBar() {
        windowCoordinator.syncNow()
    }

    func resetSyncFromStatusBar() {
        windowCoordinator.resetSync()
    }
}
