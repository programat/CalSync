//
//  StatusBarController.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import AppKit
import Combine
import os

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private weak var appCoordinator: AppCoordinator?
    private var statusObservation: AnyCancellable?
    private let logger = Logger(subsystem: "CalSync", category: "StatusBar")

    init(
        appCoordinator: AppCoordinator,
        statusPublisher: AnyPublisher<AppViewModel.Status, Never>
    ) {
        self.appCoordinator = appCoordinator
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        configureStatusItem()
        configureMenu()
        observeStatus(statusPublisher)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel("CalSync")
        button.setAccessibilityHelp("Нажмите, чтобы открыть окно CalSync.")
        apply(StatusBarPresentation(status: .idle))
    }

    private func observeStatus(_ statusPublisher: AnyPublisher<AppViewModel.Status, Never>) {
        statusObservation = statusPublisher.sink { [weak self] status in
            Task { @MainActor [weak self] in
                self?.apply(StatusBarPresentation(status: status))
            }
        }
    }

    private func apply(_ presentation: StatusBarPresentation) {
        guard let button = statusItem.button else { return }
        let symbolImage = NSImage(
            systemSymbolName: presentation.symbolName,
            accessibilityDescription: presentation.accessibilityValue
        )
        let image = symbolImage
            ?? NSImage(systemSymbolName: "calendar", accessibilityDescription: "CalSync")
        image?.isTemplate = true
        button.image = image
        button.title = presentation.isError && symbolImage == nil ? "!" : ""
        button.toolTip = presentation.toolTip
        button.contentTintColor = presentation.isError ? .systemRed : nil
        button.setAccessibilityValue(presentation.accessibilityValue)
    }

    private func configureMenu() {
        menu.addItem(NSMenuItem(
            title: "Открыть CalSync",
            action: #selector(openMainWindow),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Синхронизировать",
            action: #selector(syncNow),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: "Сбросить копии",
            action: #selector(resetSync),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Завершить CalSync",
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
        appCoordinator?.syncNowFromStatusBar()
        logger.info("Sync now triggered.")
    }

    @objc private func resetSync() {
        appCoordinator?.resetSyncFromStatusBar()
        logger.info("Reset sync triggered.")
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
