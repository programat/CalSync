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

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "CalSync",
            managedObjectModel: CalSyncManagedObjectModel.make()
        )

        let storeDescription = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true

        if inMemory {
            storeDescription.type = NSInMemoryStoreType
            storeDescription.url = URL(fileURLWithPath: "/dev/null")
        }

        container.persistentStoreDescriptions = [storeDescription]

        let logger = Logger(subsystem: "CalSync", category: "Persistence")
        container.loadPersistentStores(completionHandler: { _, error in
            if let error {
                logger.fault(
                    "Failed to load persistent store: \(error.localizedDescription, privacy: .public)"
                )
            }
        })

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(
            merge: .mergeByPropertyObjectTrumpMergePolicyType
        )
        container.viewContext.undoManager = nil
    }
}
