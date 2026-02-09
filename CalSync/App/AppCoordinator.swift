//
//  AppCoordinator.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import AppKit

final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let windowCoordinator = WindowCoordinator()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(appCoordinator: self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        windowCoordinator.showMainWindow()
        Task { @MainActor in
            await windowCoordinator.onAppStart()
        }
    }
}
