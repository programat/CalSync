//
//  SettingsStore.swift
//  CalSync
//
//  Created by Codex on 09.02.2026.
//

import Foundation

nonisolated protocol SettingsStore: AnyObject {
    var sourceCalendarId: String? { get set }
    var childCalendarId: String? { get set }
    var daysBack: Int { get set }
    var daysForward: Int { get set }
    var excludeCanceledEventsByStatus: Bool { get set }
    var useCanceledTitlePrefixFilter: Bool { get set }
    var canceledTitlePrefixes: [String] { get set }
    var isAutoSyncEnabled: Bool { get set }
    var autoSyncIntervalMinutes: Int { get set }
}

nonisolated final class UserDefaultsSettingsStore: SettingsStore {
    static let defaultDaysBack = 30
    static let defaultDaysForward = 90
    static let defaultExcludeCanceledEventsByStatus = false
    static let defaultUseCanceledTitlePrefixFilter = false
    static let defaultCanceledTitlePrefixes = CanceledTitlePrefixRules.defaultPrefixes
    static let defaultIsAutoSyncEnabled = true
    static let defaultAutoSyncIntervalMinutes = 15
    static let autoSyncIntervalMinutesRange = 1...1_440

    private enum Key {
        static let sourceCalendarId = "settings.sourceCalendarId"
        static let childCalendarId = "settings.childCalendarId"
        static let daysBack = "settings.daysBack"
        static let daysForward = "settings.daysForward"
        static let excludeCanceledEvents = "settings.excludeCanceledEvents"
        static let useCanceledTitlePrefixFilter = "settings.useCanceledTitlePrefixFilter"
        static let canceledTitlePrefixes = "settings.canceledTitlePrefixes"
        static let isAutoSyncEnabled = "settings.autoSyncEnabled"
        static let autoSyncIntervalMinutes = "settings.autoSyncIntervalMinutes"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if userDefaults.object(forKey: Key.useCanceledTitlePrefixFilter) == nil {
            let prefixFilterValue = userDefaults.object(forKey: Key.excludeCanceledEvents) == nil
                ? Self.defaultUseCanceledTitlePrefixFilter
                : userDefaults.bool(forKey: Key.excludeCanceledEvents)
            userDefaults.set(prefixFilterValue, forKey: Key.useCanceledTitlePrefixFilter)
        }
    }

    var sourceCalendarId: String? {
        get { userDefaults.string(forKey: Key.sourceCalendarId) }
        set { setOptionalString(newValue, forKey: Key.sourceCalendarId) }
    }

    var childCalendarId: String? {
        get { userDefaults.string(forKey: Key.childCalendarId) }
        set { setOptionalString(newValue, forKey: Key.childCalendarId) }
    }

    var daysBack: Int {
        get {
            if userDefaults.object(forKey: Key.daysBack) == nil {
                return Self.defaultDaysBack
            }
            return userDefaults.integer(forKey: Key.daysBack)
        }
        set { userDefaults.set(newValue, forKey: Key.daysBack) }
    }

    var daysForward: Int {
        get {
            if userDefaults.object(forKey: Key.daysForward) == nil {
                return Self.defaultDaysForward
            }
            return userDefaults.integer(forKey: Key.daysForward)
        }
        set { userDefaults.set(newValue, forKey: Key.daysForward) }
    }

    var excludeCanceledEventsByStatus: Bool {
        get {
            if userDefaults.object(forKey: Key.excludeCanceledEvents) == nil {
                return Self.defaultExcludeCanceledEventsByStatus
            }
            return userDefaults.bool(forKey: Key.excludeCanceledEvents)
        }
        set { userDefaults.set(newValue, forKey: Key.excludeCanceledEvents) }
    }

    var useCanceledTitlePrefixFilter: Bool {
        get { userDefaults.bool(forKey: Key.useCanceledTitlePrefixFilter) }
        set { userDefaults.set(newValue, forKey: Key.useCanceledTitlePrefixFilter) }
    }

    var canceledTitlePrefixes: [String] {
        get {
            guard let storedPrefixes = userDefaults.stringArray(forKey: Key.canceledTitlePrefixes) else {
                return Self.defaultCanceledTitlePrefixes
            }
            return CanceledTitlePrefixRules.normalized(storedPrefixes)
        }
        set {
            userDefaults.set(
                CanceledTitlePrefixRules.normalized(newValue),
                forKey: Key.canceledTitlePrefixes
            )
        }
    }

    var isAutoSyncEnabled: Bool {
        get {
            if userDefaults.object(forKey: Key.isAutoSyncEnabled) == nil {
                return Self.defaultIsAutoSyncEnabled
            }
            return userDefaults.bool(forKey: Key.isAutoSyncEnabled)
        }
        set { userDefaults.set(newValue, forKey: Key.isAutoSyncEnabled) }
    }

    var autoSyncIntervalMinutes: Int {
        get {
            guard userDefaults.object(forKey: Key.autoSyncIntervalMinutes) != nil else {
                return Self.defaultAutoSyncIntervalMinutes
            }
            return Self.clampAutoSyncIntervalMinutes(
                userDefaults.integer(forKey: Key.autoSyncIntervalMinutes)
            )
        }
        set {
            userDefaults.set(
                Self.clampAutoSyncIntervalMinutes(newValue),
                forKey: Key.autoSyncIntervalMinutes
            )
        }
    }

    static func clampAutoSyncIntervalMinutes(_ value: Int) -> Int {
        min(
            max(value, autoSyncIntervalMinutesRange.lowerBound),
            autoSyncIntervalMinutesRange.upperBound
        )
    }

    private func setOptionalString(_ value: String?, forKey key: String) {
        guard let value else {
            userDefaults.removeObject(forKey: key)
            return
        }
        userDefaults.set(value, forKey: key)
    }
}
