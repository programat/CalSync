//
//  CalSyncApp.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import SwiftUI

@main
struct CalSyncApp: App {
    @NSApplicationDelegateAdaptor(AppCoordinator.self) private var appCoordinator

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
