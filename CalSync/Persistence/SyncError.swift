//
//  SyncError.swift
//  CalSync
//
//  Explicit Core Data class shared by Xcode and SwiftPM builds.
//

import CoreData
import Foundation

@objc(SyncError)
nonisolated final class SyncError: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var timestamp: Date?
    @NSManaged var message: String?
    @NSManaged var context: String?

    @nonobjc class func fetchRequest() -> NSFetchRequest<SyncError> {
        NSFetchRequest<SyncError>(entityName: "SyncError")
    }
}
