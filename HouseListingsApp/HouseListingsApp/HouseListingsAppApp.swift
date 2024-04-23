//
//  HouseListingsAppApp.swift
//  HouseListingsApp
//
//  Created by Richard Matejka on 3/16/24.
//

import SwiftUI

@main
struct HouseListingsAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
