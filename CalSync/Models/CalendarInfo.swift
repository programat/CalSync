//
//  CalendarInfo.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import Foundation

struct CalendarInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let sourceTitle: String?
    let isWritable: Bool
}
