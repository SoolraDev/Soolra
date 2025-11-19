//
//  ImagePicker.swift
//  SOOLRA
//
//  Created by Michael Essiet on 19/11/2025.
//

import PhotosUI
import SwiftUI

struct ImagePicker: UIViewControllerRepresentable {
    // A binding to the image that will be selected by the user.
    @Binding var image: UIImage?

    // This creates the coordinator that will handle events from the picker.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Creates the PHPickerViewController instance.
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images  // We only want to select images.
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator  // Set the delegate to our coordinator.
        return picker
    }

    // This is required but we don't need to update the view controller.
    func updateUIViewController(
        _ uiViewController: PHPickerViewController,
        context: Context
    ) {}

    // The coordinator class acts as the delegate for the PHPickerViewController.
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        // This delegate method is called when the user finishes picking photos.
        func picker(
            _ picker: PHPickerViewController,
            didFinishPicking results: [PHPickerResult]
        ) {
            picker.dismiss(animated: true)

            // Ensure the user selected a photo.
            guard let provider = results.first?.itemProvider else { return }

            // Check if the provider can load a UIImage object.
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    // Update the parent's binding on the main thread.
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
}
