//
//  MainWindowView.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import SwiftUI

struct MainWindowView: View {
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: InterfaceMetrics.sectionSpacing) {
                    CalendarSettingsView()
                    SyncPreferencesView()
                    SyncStatusView()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(InterfaceMetrics.cardPadding)
            }
            Divider()
            SyncActionBar()
        }
        .frame(minWidth: 640, minHeight: 540)
    }
}

struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView()
            .environmentObject(AppViewModel())
    }
}
