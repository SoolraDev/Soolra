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

        let state = SaveState(id: id, name: name, gameName: emulator.gameName, date: Date(), saveFileName: svsFile, thumbnailFileName: thumbFile)
        saveStates.insert(state, at: 0)

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
    
    func states(for gameName: String) -> [SaveState] {
        saveStates.filter { $0.gameName == gameName }
    }

}



final class ScreenshotSaver {
    static func saveRGB565BufferAsPNG(
        buffer: UnsafeMutablePointer<UInt16>,
        width: Int,
        height: Int,
        to url: URL
    ) {
        let count = width * height

        // Copy buffer to avoid mutating the original memory
        let bufferCopy = UnsafeMutableBufferPointer<UInt16>.allocate(capacity: count)
        memcpy(bufferCopy.baseAddress, buffer, count * MemoryLayout<UInt16>.stride)

        // Create RGBA8888 buffer
        let rgbaData = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: count * 4)

        for i in 0..<count {
            let pixel = bufferCopy[i]
            let r = UInt8(((pixel >> 11) & 0x1F) * 255 / 31)
            let g = UInt8(((pixel >> 5) & 0x3F) * 255 / 63)
            let b = UInt8((pixel & 0x1F) * 255 / 31)

            let offset = i * 4
            rgbaData[offset] = r
            rgbaData[offset + 1] = g
            rgbaData[offset + 2] = b
            rgbaData[offset + 3] = 255 // Alpha
        }

        let bytesPerRow = width * 4

        guard let context = CGContext(
            data: rgbaData.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ), let cgImage = context.makeImage() else {
            print("❌ Failed to create CGContext or CGImage")
            bufferCopy.deallocate()
            rgbaData.deallocate()
            return
        }

        let image = UIImage(cgImage: cgImage)
        if let data = image.pngData() {
            do {
                try data.write(to: url)
                print("✅ Screenshot saved to \(url.path)")
            } catch {
                print("❌ Failed to write screenshot: \(error)")
            }
        }

        bufferCopy.deallocate()
        rgbaData.deallocate()
    }
}
