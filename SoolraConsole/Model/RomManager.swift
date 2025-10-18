//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import Foundation
import CoreData
import ZIPFoundation
import UIKit
import FirebaseAnalytics

class RomManager {
    private let context: NSManagedObjectContext
    private let saveStateManager: SaveStateManager
    
    init(context: NSManagedObjectContext, saveStateManager: SaveStateManager) {
        self.context = context
        self.saveStateManager = saveStateManager
        countDefaultRomsinBundleOnFirstLaunch()
    }
    
    
    // MARK: - Public Methods
    func fetchRoms() -> [Rom] {
        let request = NSFetchRequest<Rom>(entityName: "Rom")
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Rom.createdAt), ascending: false),
            NSSortDescriptor(key: #keyPath(Rom.name), ascending: true)
        ]
        
        
        do {
            let roms = try context.fetch(request)
            let soolraDirectory = getSoolraDirectory()
            
            // Update URLs to use current Soolra directory
            for rom in roms {
                if let url = rom.url {
                    let currentUrl = soolraDirectory.appendingPathComponent(url.lastPathComponent)
                    rom.url = currentUrl
                    rom.isValid = FileManager.default.fileExists(atPath: currentUrl.path)
                }
            }
            save()
            
            return roms
        } catch {
            print("Error fetching ROMs: \(error)")
            return []
        }
    }
    
    func addRom(url: URL) async {
        let needsRelease = setupSecurityScope(for: url)
        defer {
            if needsRelease {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            if url.pathExtension == "zip" {
                try await handleZipFile(url)
            } else if isValidRomExtension(url.pathExtension) {
                guard let romName = getRomName(from: url) else {
                    print("Invalid ROM file name")
                    return
                }
                
                if romExists(name: romName, url: url) {
                    print("ROM '\(romName)' already exists")
                    return
                }
                
                try await handleRomFile(url, romName: romName)
            } else {
                print("Unsupported file type")
            }
        } catch {
            print("Error adding ROM: \(error.localizedDescription)")
        }
    }
    
    private func isValidRomExtension(_ extension: String) -> Bool {
        return ConsoleCoreManager.ConsoleType.allFileExtensions.contains(`extension`.lowercased())
    }
    
    private func handleRomFile(_ url: URL, romName: String) async throws {
        let soolraDirectory = getSoolraDirectory()
        let destinationURL = soolraDirectory.appendingPathComponent(url.lastPathComponent)
        
        try FileManager.default.copyItem(at: url, to: destinationURL)
        await createRomEntity(name: romName, url: destinationURL)
        Analytics.logEvent("rom_added", parameters: [
            "rom_name": romName,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    private func handleZipFile(_ url: URL) async throws {
        let soolraDirectory = getSoolraDirectory()
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        
        // First, extract all files to temp directory
        try extractZipFile(at: url, to: tempDirectory)
        
        // Then process each extracted file
        let items = try FileManager.default.contentsOfDirectory(atPath: tempDirectory.path)
        for romFile in items.filter({ isValidRomExtension(URL(fileURLWithPath: $0).pathExtension) }) {
            let tempRomUrl = tempDirectory.appendingPathComponent(romFile)
            guard let romName = getRomName(from: tempRomUrl) else {
                continue
            }
            
            let destinationURL = soolraDirectory.appendingPathComponent(romFile)
            
            if romExists(name: romName, url: destinationURL) {
                print("ROM '\(romName)' already exists in CoreData, skipping...")
                continue
            }
            
            // If file exists in Soolra but not in CoreData, use it
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                print("ROM file exists but not in CoreData, adding to CoreData: \(romName)")
                await createRomEntity(name: romName, url: destinationURL)
                continue
            }
            
            // If neither exists, move the file and create entity
            do {
                try FileManager.default.moveItem(at: tempRomUrl, to: destinationURL)
                await createRomEntity(name: romName, url: destinationURL)
                Analytics.logEvent("rom_added", parameters: [
                    "rom_name": romName,
                    "timestamp": Date().timeIntervalSince1970
                ])
            } catch {
                print("Error moving ROM file \(romName): \(error.localizedDescription)")
            }
        }
    }
    
    private func extractZipFile(at url: URL, to destination: URL) throws {
        do {
            let archive = try Archive(url: url, accessMode: .read)
            // Extract all valid ROM types
            for entry in archive {
                let entryExtension = URL(fileURLWithPath: entry.path).pathExtension.lowercased()
                if isValidRomExtension(entryExtension) {
                    let destinationURL = destination.appendingPathComponent(entry.path)
                    _ = try archive.extract(entry, to: destinationURL)
                    print("Extracted \(entry.path) to \(destinationURL.path)")
                }
            }
        } catch {
            throw NSError(domain: "ZipError",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to extract zip file: \(error.localizedDescription)"])
        }
    }
    
    func deleteRom(rom: Rom) {
        guard let url = rom.url else {
            context.delete(rom)
            save()
            return
        }
        
        let soolraDirectory = getSoolraDirectory()
        let currentUrl = soolraDirectory.appendingPathComponent(url.lastPathComponent)
        
        do {
            if FileManager.default.fileExists(atPath: currentUrl.path) {
                try FileManager.default.removeItem(at: currentUrl)
                print("Successfully deleted ROM file at: \(currentUrl.path)")
            }
            saveStateManager.deleteAllStates(rom)
        } catch {
            print("Failed to delete ROM file: \(error.localizedDescription)")
        }
        
        context.delete(rom)
        save()
        UserDefaults.standard.addDeletedROM(name: getRomName(from: currentUrl) ?? "")
    }
    
    // MARK: - Private Methods - File Management
    
    private func getRomName(from url: URL) -> String? {
        let filename = url.lastPathComponent
        let fileExtension = url.pathExtension.lowercased()
        
        // Use ConsoleType to validate the extension
        guard ConsoleCoreManager.ConsoleType.from(fileExtension: fileExtension) != nil else {
            return nil
        }
        
        return String(filename.dropLast(fileExtension.count + 1)) // +1 for the dot
    }
    
    private func getConsoleType(from url: URL) -> ConsoleCoreManager.ConsoleType? {
        return ConsoleCoreManager.ConsoleType.from(fileExtension: url.pathExtension.lowercased())
    }
    
    private func setupSecurityScope(for url: URL) -> Bool {
        return !url.isFileURL || url.startAccessingSecurityScopedResource()
    }
    
    private func getSoolraDirectory() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let soolraDirectory = documentsURL.appendingPathComponent("Soolra")
        
        if !FileManager.default.fileExists(atPath: soolraDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: soolraDirectory,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
            } catch {
                print("Error creating Soolra folder: \(error.localizedDescription)")
            }
        }
        
        return soolraDirectory
    }
    
    
    
    // MARK: - Private Methods - CoreData
    private func createRomEntity(name: String, url: URL) async {
        let soolraDirectory = getSoolraDirectory()
        let relativeUrl = soolraDirectory.appendingPathComponent(url.lastPathComponent)
        
        let imageData: Data? = await {
            do {
                if let consoleType = getConsoleType(from: url),
                   let image = try await RomArtworkLoader.shared.getRomArtwork(romName: name,
                                                                               consoleType: consoleType) {
                    return image.pngData()
                }
            } catch let error as RomArtworkLoader.TimeoutError {
                print("Artwork fetch timed out for '\(name)': \(error.message)")
            } catch {
                print("Failed to fetch artwork for '\(name)': \(error)")
            }
            return nil
        }()
        
        await MainActor.run {
            let rom = Rom(context: context)
            rom.name = name
            rom.url = relativeUrl
            rom.isValid = FileManager.default.fileExists(atPath: relativeUrl.path)
            rom.imageData = imageData
            rom.consoleType = getConsoleType(from: url)?.rawValue ?? "unknown"
            rom.createdAt    = Date()
            save()
        }
    }
    
    private func romExists(name: String, url: URL) -> Bool {
        guard let consoleType = getConsoleType(from: url)?.rawValue else {
            return false
        }
        
        let fetchRequest: NSFetchRequest<Rom> = Rom.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND consoleType == %@", name, consoleType)
        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            print("Error checking for duplicate ROM: \(error.localizedDescription)")
            return false
        }
    }
    
    private func save() {
        do {
            try context.save()
        } catch {
            print("Failed to save ROM: \(error.localizedDescription)")
        }
    }
    
    func initDefaultRoms() async {
        let fm = FileManager.default
        guard let resourceURL = Bundle.main.resourceURL else { return }
        let destDir = getSoolraDirectory()
        
        do {
            let allFiles = try fm.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil)
//            let romsDirectory = resourceURL.appendingPathComponent("BundledRoms/ROMs")
//            let allFiles = try fm.contentsOfDirectory(at: romsDirectory, includingPropertiesForKeys: nil)

            for file in allFiles {
                let ext = file.pathExtension.lowercased()
                guard ConsoleCoreManager.ConsoleType.allFileExtensions.contains(ext) else { continue }
                
                guard let romName = getRomName(from: file) else {
                    print("⚠️ Skipping file with invalid ROM name: \(file.lastPathComponent)")
                    continue
                }
                
                guard !UserDefaults.standard.isROMDeleted(romName) else { continue }
                
                let dest = destDir.appendingPathComponent(file.lastPathComponent)
                let exists = fm.fileExists(atPath: dest.path)
                
                // Always create the ROM entity regardless of copy status
                if !romExists(name: romName, url: dest) {
                    await createRomEntity(name: romName, url: dest)
                }
                
                // Copy file in background if not already copied
                if !exists {
                    DispatchQueue.global(qos: .utility).async {
                        do {
                            try fm.copyItem(at: file, to: dest)
                            print("✅ Copied \(file.lastPathComponent)")
                        } catch {
                            print("❌ Failed to copy \(file.lastPathComponent): \(error)")
                        }
                    }
                }
            }
        } catch {
            print("❌ initDefaultRoms failed:", error)
        }
    }
    

    
    func countDefaultRomsinBundleOnFirstLaunch() {
        guard UserDefaults.standard.object(forKey: "numOfDefaultRomsInBundle") == nil else {
            return
        }
        let fileManager = FileManager.default
        guard let resourceURL = Bundle.main.resourceURL else {
            print("❌ Resource URL not found.")
            UserDefaults.standard.setNumOfdefaultRomsInBundle(to: 0)
            return
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil)
            let count = files.filter { url in
                ConsoleCoreManager.ConsoleType.allFileExtensions.contains(url.pathExtension.lowercased())
            }.count
            
            UserDefaults.standard.setNumOfdefaultRomsInBundle(to: count)
        } catch {
            print("❌ Failed to count default ROMs: \(error)")
            UserDefaults.standard.setNumOfdefaultRomsInBundle(to: 0)
        }
    }
    
    func resetDeletedDefaultRoms() {
        UserDefaults.standard.deletedDefaultRoms.removeAll()
    }
    
}

extension UserDefaults {
    private var deletedROMsKey: String { "deletedDefaultRoms" }
    private var numOfdefaultRomsInBundleKey: String { "numOfdefaultRomsInBundle" }
    
    var deletedDefaultRoms: Set<String> {
        get {
            return Set(array(forKey: deletedROMsKey) as? [String] ?? [])
        }
        set {
            set(Array(newValue), forKey: deletedROMsKey)
        }
    }
    
    var numOfdefaultRomsInBundle: Int {
        get {
            integer(forKey: numOfdefaultRomsInBundleKey)
        }
        set {
            set(newValue, forKey: numOfdefaultRomsInBundleKey)
        }
    }
    
    
    func addDeletedROM(name: String) {
        var current = deletedDefaultRoms
        current.insert(name)
        deletedDefaultRoms = current
    }
    
    func isROMDeleted(_ name: String) -> Bool {
        return deletedDefaultRoms.contains(name)
    }
    
    func setNumOfdefaultRomsInBundle(to count: Int) {
        if object(forKey: "numOfdefaultRomsInBundle") == nil {
            set(count, forKey: "numOfdefaultRomsInBundle")
        }
    }
    
    
    
    
}


class RomArtworkLoader {
    static let shared = RomArtworkLoader()
    private init() {}
    
    public struct TimeoutError: Error {
        public let message = "Artwork fetch timed out after 6 seconds"
    }
    
    // Load pre-computed list of available boxart filenames for each console type
    private lazy var availableBoxartFilenames: [ConsoleCoreManager.ConsoleType: [String]] = {
        var filenames: [ConsoleCoreManager.ConsoleType: [String]] = [:]
        
        // Map of console types to their boxart filename resources
        let resourceMapping: [ConsoleCoreManager.ConsoleType: String] = [
            .nes: "nes_boxart_filenames",
            .gba: "gba_boxart_filenames"
        ]
        
        // Load filenames for each console type
        for (consoleType, resource) in resourceMapping {
            if let path = Bundle.main.path(forResource: resource, ofType: "txt"),
               let content = try? String(contentsOfFile: path) {
                let consoleFilenames = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
                filenames[consoleType] = consoleFilenames
            }
        }
        
        return filenames
    }()
    
    // Compute Levenshtein distance between two strings
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let m = str1.count
        let n = str2.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            dp[i][0] = i
        }
        
        for j in 0...n {
            dp[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                let index1 = str1.index(str1.startIndex, offsetBy: i-1)
                let index2 = str2.index(str2.startIndex, offsetBy: j-1)
                
                if str1[index1] == str2[index2] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]) + 1
                }
            }
        }
        
        return dp[m][n]
    }
    
    private func findClosestMatchingFilename(for romName: String, consoleType: ConsoleCoreManager.ConsoleType) -> String? {
        guard let consoleFilenames = availableBoxartFilenames[consoleType] else {
            return nil
        }
        
        // Clean and normalize ROM name
        let cleanedRomName = romName
            .replacingOccurrences(of: "(Rev \\d+)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Filter and sort filenames
        let matchedFilenames = consoleFilenames
            .filter { $0.contains(cleanedRomName) }
            .sorted {
                // Prioritize filenames that are most similar in length
                abs($0.count - romName.count) < abs($1.count - romName.count)
            }
        
        // Return first match or minimum distance match
        return matchedFilenames.first ?? consoleFilenames.min { a, b in
            let distanceA = levenshteinDistance(cleanedRomName, a.replacingOccurrences(of: ".png", with: ""))
            let distanceB = levenshteinDistance(cleanedRomName, b.replacingOccurrences(of: ".png", with: ""))
            return distanceA < distanceB
        }
    }
    
    func getRomArtwork(romName: String, consoleType: ConsoleCoreManager.ConsoleType) async throws -> UIImage? {
        
        if let localURL = Bundle.main.url(forResource: romName, withExtension: "png"),
           let data = try? Data(contentsOf: localURL),
           let image = UIImage(data: data) {
            return image
        }
//        if let localURL = Bundle.main.url(forResource: romName, withExtension: "png", subdirectory: "BundledRoms/Artwork"),
//           let data = try? Data(contentsOf: localURL),
//           let image = UIImage(data: data) {
//            return image
//        }

        
        // Try with closest matching filename within timeout
        return try await withTimeout(seconds: 10) {
            
            if let matchedFilename = self.findClosestMatchingFilename(for: romName, consoleType: consoleType),
               let image = try await self.fetchArtwork(for: matchedFilename.replacingOccurrences(of: ".png", with: ""), consoleType: consoleType, originalFilename: romName) {
                print("Found artwork for \(romName) (\(consoleType)): \(matchedFilename)")
                return image
            }
            return nil
        }
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            // Return the first successful result or throw the first error
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            // Cancel any remaining tasks
            group.cancelAll()
            
            return result
        }
    }
    
    private func fetchArtwork(for romName: String, consoleType: ConsoleCoreManager.ConsoleType, originalFilename: String) async throws -> UIImage? {
        
        let platformMapping: [ConsoleCoreManager.ConsoleType: String] = [
            .nes: "Nintendo%20-%20Nintendo%20Entertainment%20System",
            .gba: "Nintendo%20-%20Game%20Boy%20Advance"
        ]
        
        guard let platform = platformMapping[consoleType] else { return nil }
        
        let romNameUrl = romName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? romName
        let urlString = "https://thumbnails.libretro.com/\(platform)/Named_Boxarts/\(romNameUrl).png"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("Failed to download artwork for '\(romName)' (\(consoleType)): \(error)")
            return nil
        }
    }
    
    
}
