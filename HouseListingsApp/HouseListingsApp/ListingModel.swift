//
//  ListingModel.swift
//  HouseListingsApp
//
//  Created by Richard Matejka on 3/16/24.
//

import Foundation
import MapKit

struct ListingModel: Identifiable, Codable {
    var id = UUID()
    var address: String
    var summary: String
    var value: Double
    var latitude: Double
    var longitude: Double
    var coordinates: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
}

//extension ListingModel {
//    init(entity: ListingEntity) {
//        //self.id = entity.id ?? UUID() // Provide a new UUID if nil, or handle appropriately
//        self.address = entity.address ?? "Unknown Address"
//        self.summary = entity.summary ?? "No summary available"
//        self.value = entity.value
//        self.latitude = entity.latitude
//        self.longitude = entity.longitude
//    }
//}

struct ApiResponse: Codable {
    let property: [Property]
}

struct Property: Codable {
    let address: Address?
    let location: Location?
    let summary: Summary?
    let avm: Avm?
    
    func toHouseListing() -> ListingModel {
        return ListingModel(
            address: self.address?.oneLine ?? "N/A",
            summary: self.summary?.propclass ?? "N/A",
            value: self.avm?.amount?.value ?? 0.0,
            latitude: Double(self.location?.latitude ?? "0.0") ?? 0.0,
            longitude: Double(self.location?.longitude ?? "0.0") ?? 0.0
        )
    }
}

struct Address: Codable {
    let oneLine: String?
}

struct Location: Codable {
    let latitude: String?
    let longitude: String?
}

struct Summary: Codable {
    let propclass: String?
}

struct Avm: Codable {
    let amount: Amount?
}

struct Amount: Codable {
    let value: Double?
}
