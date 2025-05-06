//
//  SaveState.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 29/04/2025.
//


// SaveState.swift
import Foundation
import UIKit

struct SaveState: Codable, Identifiable {
    let id: UUID
    var name: String?
    var gameName: String
    var date: Date
    var saveFileName: String
    var thumbnailFileName: String

    var localizedName: String {
        name ?? DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }
}

// SaveStateManager.swift
import Foundation
import UIKit

class SaveStateManager: ObservableObject {
    static let shared = SaveStateManager()

    private let metadataURL: URL
    private let savesDirectory: URL

    @Published private(set) var saveStates: [SaveState] = []

    private init() {
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        savesDirectory = documents.appendingPathComponent("SaveStates")
        metadataURL = savesDirectory.appendingPathComponent("metadata.json")

        try? fileManager.createDirectory(at: savesDirectory, withIntermediateDirectories: true)
        loadSaveStates()
    }

    func loadSaveStates() {
        guard let data = try? Data(contentsOf: metadataURL) else { return }
        guard let decoded = try? JSONDecoder().decode([SaveState].self, from: data) else { return }
        saveStates = decoded.sorted { $0.date > $1.date }
    }

    func persist() {
        let data = try? JSONEncoder().encode(saveStates)
        try? data?.write(to: metadataURL)
    }

    func saveNewState(from emulator: ConsoleCoreManager, name: String?) {
        let id = UUID()
        let svsFile = "\(id).svs"
        let thumbFile = "\(id).png"
        let saveURL = savesDirectory.appendingPathComponent(svsFile)
        let thumbnailURL = savesDirectory.appendingPathComponent(thumbFile)

        emulator.saveState(to: saveURL)
        emulator.captureScreenshot(to: thumbnailURL)

        let state = SaveState(id: id, name: name, gameName: emulator.getCurrentGameName(), date: Date(), saveFileName: svsFile, thumbnailFileName: thumbFile)
        saveStates.append(state)
        persist()
    }

    func load(state: SaveState, into emulator: ConsoleCoreManager) {
        let url = savesDirectory.appendingPathComponent(state.saveFileName)
        emulator.loadState(from: url)
    }

    func delete(state: SaveState) {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: savesDirectory.appendingPathComponent(state.saveFileName))
        try? fileManager.removeItem(at: savesDirectory.appendingPathComponent(state.thumbnailFileName))
        saveStates.removeAll { $0.id == state.id }
        persist()
    }

    func thumbnail(for state: SaveState) -> UIImage? {
        let url = savesDirectory.appendingPathComponent(state.thumbnailFileName)
        return UIImage(contentsOfFile: url.path)
    }
}

