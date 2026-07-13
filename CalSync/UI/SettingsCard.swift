//
//  SettingsCard.swift
//  CalSync
//
//  Created by Codex on 12.07.2026.
//

import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String?
    let systemImage: String?
    private let content: Content

    init(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    init(@ViewBuilder content: () -> Content) {
        title = nil
        systemImage = nil
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InterfaceMetrics.sectionSpacing) {
            if let title, let systemImage {
                Label(title, systemImage: systemImage)
                    .font(.headline)
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(InterfaceMetrics.cardPadding)
        .background(
            Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: InterfaceMetrics.cardRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: InterfaceMetrics.cardRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}
