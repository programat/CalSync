//
//  StatusBarController.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import AppKit
import os

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private weak var appCoordinator: AppCoordinator?
    private let logger = Logger(subsystem: "CalSync", category: "StatusBar")

    init(appCoordinator: AppCoordinator) {
        self.appCoordinator = appCoordinator
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        configureStatusItem()
        configureMenu()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "CalSync")
        image?.isTemplate = true
        button.image = image
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureMenu() {
        menu.addItem(NSMenuItem(
            title: "Open",
            action: #selector(openMainWindow),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Sync now",
            action: #selector(syncNow),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: "Reset sync",
            action: #selector(resetSync),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))
        menu.items.forEach { $0.target = self }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            openMainWindow()
        }
    }

    private func showMenu() {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openMainWindow() {
        appCoordinator?.showMainWindow()
    }

    @objc private func syncNow() {
        logger.info("Sync now triggered (stub)")
    }

    @objc private func resetSync() {
        logger.info("Reset sync triggered (stub)")
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
