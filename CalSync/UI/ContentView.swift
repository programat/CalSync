//
//  ContentView.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("CalSync")
                .font(.headline)
            Text("Use menu bar to open the main window.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 320, minHeight: 200)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
