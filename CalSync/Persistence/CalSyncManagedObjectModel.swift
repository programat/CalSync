//
//  CalSyncManagedObjectModel.swift
//  CalSync
//
//  Programmatic model keeps Core Data available to Command Line Tools builds.
//

import CoreData

nonisolated enum CalSyncManagedObjectModel {
    private static let shared = build()

    static func make() -> NSManagedObjectModel {
        shared
    }

    private static func build() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [makeSyncedEventLinkEntity(), makeSyncErrorEntity()]
        return model
    }

    private static func makeSyncedEventLinkEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SyncedEventLink"
        entity.managedObjectClassName = NSStringFromClass(SyncedEventLink.self)
        entity.properties = [
            attribute("id", type: .UUIDAttributeType),
            attribute("sourceCalendarId", type: .stringAttributeType),
            attribute("childCalendarId", type: .stringAttributeType),
            attribute("sourceEventId", type: .stringAttributeType, isOptional: true),
            attribute("sourceCalendarItemId", type: .stringAttributeType, isOptional: true),
            attribute("sourceOccurrenceDate", type: .dateAttributeType, isOptional: true),
            attribute("sourceStartLastSeen", type: .dateAttributeType),
            attribute("sourceEndLastSeen", type: .dateAttributeType),
            attribute("childEventId", type: .stringAttributeType),
            attribute("lastSyncedAt", type: .dateAttributeType),
            attribute("lastSeenInSourceAt", type: .dateAttributeType),
            attribute("lastSyncHash", type: .stringAttributeType),
        ]
        return entity
    }

    private static func makeSyncErrorEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SyncError"
        entity.managedObjectClassName = NSStringFromClass(SyncError.self)
        entity.properties = [
            attribute("id", type: .UUIDAttributeType),
            attribute("timestamp", type: .dateAttributeType),
            attribute("message", type: .stringAttributeType),
            attribute("context", type: .stringAttributeType, isOptional: true),
        ]
        return entity
    }

    private static func attribute(
        _ name: String,
        type: NSAttributeType,
        isOptional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        return attribute
    }
}
