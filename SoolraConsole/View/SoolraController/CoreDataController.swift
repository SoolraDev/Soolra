//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import CoreData
import Foundation

class CoreDataController: ObservableObject {
    let container = NSPersistentContainer(name: "Model")
    let romManager: RomManager
    
    init() {
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        self.romManager = RomManager(context: container.viewContext)
    }

    static func isFirstLaunch() -> Bool {
        let defaults = UserDefaults.standard
        let key = "First Launch"

        defer {
            defaults.set(true, forKey: key)
        }

        return defaults.bool(forKey: key) == false
    }
}
