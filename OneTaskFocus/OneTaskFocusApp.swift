//
//  OneTaskFocusApp.swift
//  OneTaskFocus
//
//  Created by Tam Le on 3/12/26.
//

import SwiftUI
import SwiftData

@main
struct OneTaskFocusApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FocusSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
