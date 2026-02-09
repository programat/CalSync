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
}

nonisolated final class UserDefaultsSettingsStore: SettingsStore {
    static let defaultDaysBack = 30
    static let defaultDaysForward = 90

    private enum Key {
        static let sourceCalendarId = "settings.sourceCalendarId"
        static let childCalendarId = "settings.childCalendarId"
        static let daysBack = "settings.daysBack"
        static let daysForward = "settings.daysForward"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
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

    private func setOptionalString(_ value: String?, forKey key: String) {
        guard let value else {
            userDefaults.removeObject(forKey: key)
            return
        }
        userDefaults.set(value, forKey: key)
    }
}
