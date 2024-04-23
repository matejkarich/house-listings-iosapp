//
//  ListingViewModel.swift
//  HouseListingsApp
//
//  Created by Richard Matejka on 3/16/24.
//

import Foundation
import CoreLocation
import CoreData
import SwiftUI

class ListingViewModel: ObservableObject {
    @Published var listings: [ListingModel] = []
    @Published var favorites: [ListingEntity] = []
    private var networkService = NetworkService()
    @Published var locationDataManager = LocationDataManager()
    @Published var isLoading = false
    
    func fetchListings(latitude: Double, longitude: Double, radius: Int) {
        isLoading = true
        networkService.fetchListings(latitude: latitude, longitude: longitude, radius: radius) { [weak self] properties in
            self?.listings = properties.map { $0.toHouseListing() }
            self?.isLoading = false
        }
    }

}

class LocationDataManager : NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locationManager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            authorizationStatus = .authorizedWhenInUse
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager.requestLocation()
            manager.startUpdatingLocation()
            break
            
        case .restricted:
            authorizationStatus = .restricted
            break
            
        case .denied:
            authorizationStatus = .denied
            break
            
        case .notDetermined:  
            authorizationStatus = .notDetermined
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            manager.requestWhenInUseAuthorization()
            manager.startUpdatingLocation()
            break
            
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.first else {return}
        DispatchQueue.main.async {
            self.currentLocation = userLocation
        }
        print(userLocation.coordinate.latitude)
        print(userLocation.coordinate.longitude)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("error: \(error.localizedDescription)")
    }
    
}

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "HouseListingsCoreData")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

struct NetworkService {
    let baseURL = "https://api.gateway.attomdata.com/propertyapi/v1.0.0/allevents/detail"
    let apiKey = "3bbe7ea901af7a04ba938cbd67d3a0fb"
    
    
    func fetchListings(latitude: Double, longitude: Double, radius: Int, completion: @escaping ([Property]) -> Void) {
        RateLimiter.shared.enqueue {
            guard let url = URL(string: "\(baseURL)?latitude=\(latitude)&longitude=\(longitude)&radius=\(radius)&minavmvalue=1") else { return }
            print("Request URL: \(url.absoluteString)")
            
            var request = URLRequest(url: url)
            request.addValue(apiKey, forHTTPHeaderField: "apikey")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Network request error: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    completion([])
                    return
                }
                
                let responseString = String(data: data, encoding: .utf8)!
                    print("Raw response: \(responseString)")
                
                do {
                    let apiResponse = try JSONDecoder().decode(ApiResponse.self, from: data)
                    print("Success")
                    DispatchQueue.main.async {
                        completion(apiResponse.property)
                    }
                } catch {
                    print("Failed to decode response: \(error)")
                    completion([])
            }
            }.resume()
        }
    }
}

class RateLimiter {
    static let shared = RateLimiter()
    private init() {}

    private var requestQueue = [() -> Void]()
    private var timer: Timer?
    private let interval: TimeInterval = 6 // Interval in seconds (10 requests per minute -> 60/10)
    
    func enqueue(request: @escaping () -> Void) {
        requestQueue.append(request)
        processNextRequest()
    }
    
    private func processNextRequest() {
        guard timer == nil, !requestQueue.isEmpty else { return }
        
        let request = requestQueue.removeFirst()
        request()
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.timer = nil
            self?.processNextRequest()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
