//
//  SyncPreferencesView.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import SwiftUI

struct SyncPreferencesView: View {
    var body: some View {
        SettingsCard {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: InterfaceMetrics.cardPadding) {
                    SyncSettingsView()
                        .frame(minWidth: 240, maxWidth: .infinity, alignment: .topLeading)
                    Divider()
                    EventFiltersView()
                        .frame(minWidth: 240, maxWidth: .infinity, alignment: .topLeading)
                }
                VStack(alignment: .leading, spacing: InterfaceMetrics.sectionSpacing) {
                    SyncSettingsView()
                    Divider()
                    EventFiltersView()
                }
            }
        }
    }
}
