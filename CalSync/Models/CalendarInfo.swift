//
//  CalendarInfo.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import Foundation

nonisolated struct CalendarInfo: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let sourceTitle: String?
    let isWritable: Bool

    var displayTitle: String {
        guard let sourceTitle, !sourceTitle.isEmpty else {
            return title
        }
        return "\(title) (\(sourceTitle))"
    }
}
