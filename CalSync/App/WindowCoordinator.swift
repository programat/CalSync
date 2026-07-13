//
//  WindowCoordinator.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class WindowCoordinator: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel = AppViewModel(eventKitGateway: EventKitGatewayImpl())

    var statusPublisher: AnyPublisher<AppViewModel.Status, Never> {
        viewModel.$status
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func onAppStart() async {
        await viewModel.onAppStart()
    }

    func showMainWindow() {
        let window = window ?? createWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func syncNow() {
        viewModel.syncNow()
    }

    func resetSync() {
        viewModel.resetSync()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func createWindow() -> NSWindow {
        let view = MainWindowView()
            .environmentObject(viewModel)
        let hostingView = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CalSync"
        window.center()
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        return window
    }
}
