//
//  ContentView.swift
//  HouseListingsApp
//
//  Created by Richard Matejka on 3/16/24.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject var viewModel = ListingViewModel()
    @ObservedObject var locationDataManager = LocationDataManager()
    @State var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    @State private var showingFavorites = false
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
//        VStack {
//            switch locationDataManager.locationManager.authorizationStatus {
//            case .authorizedWhenInUse, .authorizedAlways:
//                Text("Your current location is:")
//                Text("Latitude: \(locationDataManager.locationManager.location?.coordinate.latitude.description ?? "Error loading")")
//                Text("Longitude: \(locationDataManager.locationManager.location?.coordinate.longitude.description ?? "Error loading")")
//                
//            case .restricted, .denied:
//                Text("Current location data was restricted or denied.")
//            case .notDetermined:
//                Text("Finding your location...")
//                ProgressView()
//            default:
//                ProgressView()
//            }
//        }
        NavigationView {
            ZStack {
                VStack {
                    Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: viewModel.listings) { listing in
                        MapPin(coordinate: listing.coordinates, tint: .blue)
                    }.padding()
                    .frame(height: 300)
                    
                    List(viewModel.listings) { listing in
                        NavigationLink(destination: DetailView(listing: listing, viewModel: viewModel))
                        {
                            VStack(alignment: .leading) {
                                Text(listing.address)
                                    .font(.headline)
                                Text("Value: $\(listing.value, specifier: "%.2f")")
                                    .font(.subheadline)
                            }
                        }
                    }.padding()
                    .listStyle(GroupedListStyle())
                    NavigationLink(destination: FavoritesView(viewModel: viewModel), isActive: $showingFavorites) {
                                        EmptyView()
                                    }
                    
                }
                .navigationTitle("House Listings")
                .toolbar {
                    Button(action: {
                        showingFavorites = true
                    }) {
                        Text("Favorites")
                    }
                }
                
                if (viewModel.isLoading) {
                    ProgressView()
                        .zIndex(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.5))
                }
            }
            
        }
        .onChange(of: locationDataManager.currentLocation) { newLocation in
            if let location = newLocation {
//                viewModel.fetchListings(latitude: 33.425020, longitude: -111.965410, radius: 3)
                region.center = location.coordinate
                viewModel.fetchListings(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, radius: 3)
                
            }
        }
    }
}

struct FavoritesView: View {
    @ObservedObject var viewModel: ListingViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ListingEntity.address, ascending: true)],
        animation: .default)
    private var favorites: FetchedResults<ListingEntity>

    var body: some View {
        NavigationView {
            List {
                ForEach(favorites, id: \.self) { favorite in
                    NavigationLink(destination: FavoriteDetailView(listing: favorite, viewModel: viewModel))
                    {
                        VStack(alignment: .leading) {
                            Text(favorite.address ?? "Unknown address")
                                .font(.headline)
                            Text("Value: $\(favorite.value, specifier: "%.2f")")
                                .font(.subheadline)
                        }
                    }
                }.onDelete(perform: deleteFavorite)
                
            }
            .navigationTitle("Favorited Listings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func deleteFavorite(offsets: IndexSet) {
        withAnimation {
            offsets.map { favorites[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
}


struct DetailView: View {
    let listing: ListingModel
    var viewModel: ListingViewModel
    @State private var isFavorite = false
    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: listing.coordinates, latitudinalMeters: 500, longitudinalMeters: 500)
    }
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ListingEntity.address, ascending: true)],
        animation: .default)
    private var favorites: FetchedResults<ListingEntity>

    var body: some View {
        VStack {
            Map(coordinateRegion: .constant(region), showsUserLocation: false, annotationItems: [listing]) { listing in
                MapMarker(coordinate: listing.coordinates, tint: .red)
            }
            .frame(height: 300)
            .disabled(true)
            .cornerRadius(8)
            .padding()
            Spacer()
            Text(listing.address)
                .font(.title)
            Text("Property description: \(listing.summary)")
                .font(.headline)
            Text("Property value: $\(listing.value, specifier: "%.2f")")
                .font(.headline)
            Text("Latitude: \(listing.latitude)")
                .font(.subheadline)
            Text("Longitude: \(listing.longitude)")
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .navigationTitle("Listing Information")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(action: {
                addFavorite(add: listing.address, sum: listing.summary, val: listing.value, lat: listing.latitude, lon: listing.longitude)
                isFavorite.toggle()
            }) {
                Label("Favorite", systemImage: isFavorite ? "heart.fill" : "heart")
            }
        }
    }
    
    private func addFavorite(add: String, sum: String, val: Double, lat: Double, lon:Double) {
        withAnimation {
            let favorite = ListingEntity(context: viewContext)
            favorite.address = add
            favorite.summary = sum
            favorite.value = val
            favorite.latitude = lat
            favorite.longitude = lon
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct FavoriteDetailView: View {
    let listing: ListingEntity
    var viewModel: ListingViewModel
    @Environment(\.dismiss) private var dismiss
    private var region: MKCoordinateRegion

    init(listing: ListingEntity, viewModel: ListingViewModel) {
        self.listing = listing
        self.viewModel = viewModel
        let coordinate = CLLocationCoordinate2D(latitude: listing.latitude, longitude: listing.longitude)
        self.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
    }

    var body: some View {
        VStack {
            Map(coordinateRegion: .constant(region), showsUserLocation: false, annotationItems: [listing]) { location in
                MapMarker(coordinate: CLLocationCoordinate2D(latitude: listing.latitude, longitude: listing.longitude), tint: .red)
            }
            .frame(height: 300)
            .disabled(true)
            .cornerRadius(8)
            .padding()
            Spacer()
            Text(listing.address ?? "Unknown address")
                .font(.title)
            Text("Property description: \(listing.summary ?? "N/A")")
                .font(.headline)
            Text("Property value: $\(listing.value, specifier: "%.2f")")
                .font(.headline)
            Text("Latitude: \(listing.latitude)")
                .font(.subheadline)
            Text("Longitude: \(listing.longitude)")
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .navigationTitle("Listing Information")
    }
}
