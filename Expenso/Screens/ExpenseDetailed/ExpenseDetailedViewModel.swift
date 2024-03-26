//
//  ExpenseDetailedViewModel.swift
//  Expenso
//
//  Created by Sameer Nawaz on 31/01/21.
//

import UIKit
import CoreData

class ExpenseDetailedViewModel: ObservableObject {
    
    @Published var expenseObj: ExpenseCD
    
    @Published var alertMsg = String()
    @Published var showAlert = false
    @Published var closePresenter = false
    
    init(expenseObj: ExpenseCD) {
        self.expenseObj = expenseObj
    }
    
    func deleteNote(managedObjectContext: NSManagedObjectContext) {
        managedObjectContext.delete(expenseObj)
        do {
            try managedObjectContext.save(); closePresenter = true
        } catch { alertMsg = "\(error)"; showAlert = true }
    }
    
}
