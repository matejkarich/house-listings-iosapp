//
//  ListingEntity+CoreDataProperties.swift
//  HouseListingsApp
//
//  Created by Richard Matejka on 3/18/24.
//
//

import Foundation
import CoreData


extension ListingEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ListingEntity> {
        return NSFetchRequest<ListingEntity>(entityName: "ListingEntity")
    }

    @NSManaged public var address: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var summary: String?
    @NSManaged public var value: Double

}

extension ListingEntity : Identifiable {

}
