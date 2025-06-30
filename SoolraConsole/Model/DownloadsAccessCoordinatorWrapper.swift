//
//  DownloadsAccessCoordinatorWrapper.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 24/06/2025.
//


import SwiftUI

class DownloadsAccessCoordinatorWrapper: NSObject, ObservableObject {
    @Published var roms: [URL] = []

    private let coordinator = DownloadsAccessCoordinator()

    override init() {
        super.init()
        coordinator.onROMsScanned = { [weak self] urls in
            DispatchQueue.main.async {
                self?.roms = urls
            }
        }
    }

    func requestFolder() {
        guard let rootVC = UIApplication.shared.windows.first?.rootViewController else { return }
        coordinator.requestFolder(from: rootVC)
    }
}
