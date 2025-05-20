//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    var complete: ((URL) -> Void)?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Create UTTypes for all supported console extensions
        let supportedTypes: [UTType] = ConsoleCoreManager.ConsoleType.allFileExtensions.compactMap { ext in
            UTType(filenameExtension: ext, conformingTo: .data) ?? nil
        }
        
        // Combine with ZIP type for archive support
        let documentTypes = [UTType.zip] + supportedTypes
        
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: documentTypes, asCopy: false)
        // Create picker with document types
        
        controller.allowsMultipleSelection = false
        controller.shouldShowFileExtensions = true
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // do nothing
    }

    func makeCoordinator() -> DocumentPickerCoordinator {
        let coordinator = DocumentPickerCoordinator()
        coordinator.complete = complete
        return coordinator
    }
}

class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    var complete: ((URL) -> Void)?

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        controller.navigationController?.popViewController(animated: true)
        guard let url = urls.first else { return }

        complete?(url)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.navigationController?.popViewController(animated: true)
    }
}

struct DocumentPicker_Previews: PreviewProvider {
    static var previews: some View {
        DocumentPicker()
    }
}

struct HalfScreenDocumentPicker: View {
    var complete: (URL) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        DocumentPicker(complete: { url in
            complete(url)
            dismiss()
        })
        .frame(height: UIScreen.main.bounds.height / 2)
    }
}
