//
//  SyncedEventLink.swift
//  CalSync
//
//  Explicit Core Data class shared by Xcode and SwiftPM builds.
//

import CoreData
import Foundation

@objc(SyncedEventLink)
nonisolated final class SyncedEventLink: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var sourceCalendarId: String?
    @NSManaged var childCalendarId: String?
    @NSManaged var sourceEventId: String?
    @NSManaged var sourceCalendarItemId: String?
    @NSManaged var sourceOccurrenceDate: Date?
    @NSManaged var sourceStartLastSeen: Date?
    @NSManaged var sourceEndLastSeen: Date?
    @NSManaged var childEventId: String?
    @NSManaged var lastSyncedAt: Date?
    @NSManaged var lastSeenInSourceAt: Date?
    @NSManaged var lastSyncHash: String?

    @nonobjc class func fetchRequest() -> NSFetchRequest<SyncedEventLink> {
        NSFetchRequest<SyncedEventLink>(entityName: "SyncedEventLink")
    }
}
