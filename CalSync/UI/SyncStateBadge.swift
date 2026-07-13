//
//  SyncStateBadge.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import SwiftUI

struct SyncStateBadge: View {
    let presentation: SyncStatePresentation

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Label(presentation.title, systemImage: presentation.systemImage)
                .lineLimit(1)
            Image(systemName: presentation.systemImage)
                .accessibilityLabel(presentation.title)
        }
        .font(.caption)
        .bold()
        .foregroundStyle(toneColor)
        .help(presentation.title)
    }

    private var toneColor: Color {
        switch presentation.tone {
        case .neutral:
            return .gray
        case .active:
            return .accentColor
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}
