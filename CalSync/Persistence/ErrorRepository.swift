//
//  ErrorRepository.swift
//  CalSync
//
//  Created by Codex on 09.02.2026.
//

import CoreData
import Foundation

final class ErrorRepository {
    private let context: NSManagedObjectContext
    private let maxStoredErrors = 20

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    @discardableResult
    func addError(
        id: UUID = UUID(),
        timestamp: Date = .now,
        message: String,
        context errorContext: String? = nil
    ) throws -> SyncError {
        try context.performAndWait {
            let error = SyncError(context: context)
            error.id = id
            error.timestamp = timestamp
            error.message = message
            error.context = errorContext
            try saveIfNeeded()
            try trimExcessErrorsIfNeeded(limit: maxStoredErrors)
            return error
        }
    }

    func fetchRecent(limit: Int) throws -> [SyncError] {
        try context.performAndWait {
            let request = SyncError.fetchRequest()
            request.fetchLimit = max(limit, 0)
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            return try context.fetch(request)
        }
    }

    func deleteAll() throws {
        try context.performAndWait {
            let request = SyncError.fetchRequest()
            let errors = try context.fetch(request)
            errors.forEach(context.delete)
            try saveIfNeeded()
        }
    }

    private func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    private func trimExcessErrorsIfNeeded(limit: Int) throws {
        let request = SyncError.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        let allErrors = try context.fetch(request)

        if limit <= 0 {
            allErrors.forEach(context.delete)
        } else if allErrors.count > limit {
            allErrors.dropFirst(limit).forEach(context.delete)
        }

        try saveIfNeeded()
    }
}
