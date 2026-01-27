//
//  MainWindowView.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import SwiftUI

struct MainWindowView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CalSync")
                .font(.title)
            Text("Main window placeholder")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 240)
    }
}

#Preview {
    MainWindowView()
}
