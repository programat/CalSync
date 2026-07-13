//
//  CanceledTitlePrefixRules.swift
//  CalSync
//
//  Created by Codex on 13.07.2026.
//

import Foundation

nonisolated enum CanceledTitlePrefixRules {
    static let defaultPrefixes = ["Отменено", "Cancelled", "Canceled"]

    static func normalized(_ prefixes: [String]) -> [String] {
        var result: [String] = []

        for rawPrefix in prefixes {
            let prefix = rawPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prefix.isEmpty else { continue }
            guard !result.contains(where: { existingPrefix in
                existingPrefix.compare(
                    prefix,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: .current
                ) == .orderedSame
            }) else {
                continue
            }
            result.append(prefix)
        }

        return result
    }

    static func adding(_ rawPrefix: String, to prefixes: [String]) -> [String]? {
        let currentPrefixes = normalized(prefixes)
        let updatedPrefixes = normalized(currentPrefixes + [rawPrefix])
        return updatedPrefixes == currentPrefixes ? nil : updatedPrefixes
    }

    static func title(_ title: String, hasAnyPrefix prefixes: [String]) -> Bool {
        Self.title(title, hasAnyNormalizedPrefix: normalized(prefixes))
    }

    static func title(_ title: String, hasAnyNormalizedPrefix prefixes: [String]) -> Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return prefixes.contains { prefix in
            normalizedTitle.range(
                of: prefix,
                options: [.anchored, .caseInsensitive, .diacriticInsensitive],
                locale: .current
            ) != nil
        }
    }
}
