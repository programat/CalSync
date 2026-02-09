//
//  Persistence.swift
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

import CoreData
import os

struct PersistenceController {
    static let shared = PersistenceController()
    static let inMemory = PersistenceController(inMemory: true)
    static let preview = PersistenceController(inMemory: true)

    let container: NSPersistentContainer
    private let logger = Logger(subsystem: "CalSync", category: "Persistence")

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CalSync")

        let storeDescription = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true

        if inMemory {
            storeDescription.type = NSInMemoryStoreType
            storeDescription.url = URL(fileURLWithPath: "/dev/null")
        }

        container.persistentStoreDescriptions = [storeDescription]

        var loadError: Error?
        container.loadPersistentStores(completionHandler: { _, error in
            if let error {
                loadError = error
            }
        })

        if let loadError {
            logger.fault("Failed to load persistent store: \(loadError.localizedDescription, privacy: .public)")
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
    }
}
