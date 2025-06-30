import UIKit
import UniformTypeIdentifiers

class DownloadsAccessCoordinator: NSObject, UIDocumentPickerDelegate {
    var onROMsScanned: (([URL]) -> Void)?

    func requestFolder(from viewController: UIViewController) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        viewController.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let folderURL = urls.first else { return }

        guard folderURL.startAccessingSecurityScopedResource() else {
            print("Permission denied")
            return
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        let roms = scanROMs(in: folderURL)
        onROMsScanned?(roms)
    }

    private func scanROMs(in folder: URL) -> [URL] {
        let extensions = ["nes", "gba", "gb", "zip", "bin"]
        do {
            let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            return files.filter { extensions.contains($0.pathExtension.lowercased()) }
        } catch {
            print("Scan failed: \(error)")
            return []
        }
    }
}
