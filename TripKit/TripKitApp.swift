//
//  TripKitApp.swift
//  TripKit
//
//  Created by Rohan Chinalachaiagari on 5/16/26.
//

import SwiftUI
import CoreData

@main
struct TripKitApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
