//
//  ExpensoApp.swift
//  Expenso
//
//  Created by Sameer Nawaz on 31/01/21.
//

import SwiftUI
import CoreData

@main
struct ExpensoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showLaunchView: Bool = true
    init() {
        self.setDefaultPreferences()
    }
    
    private func setDefaultPreferences() {
        let currency = UserDefaults.standard.string(forKey: UD_EXPENSE_CURRENCY)
        if currency == nil {
            UserDefaults.standard.set("$", forKey: UD_EXPENSE_CURRENCY)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ExpenseView()
                    .environment(\.managedObjectContext, persistentContainer.viewContext)
                ZStack {
                    if showLaunchView {
                        LaunchView(showLaunchView: $showLaunchView)
                            .transition(.move(edge: .leading))
                    }
                }
                .zIndex(2.0)
            }
        }
    }
    
    var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ExpenseDiary")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
}
