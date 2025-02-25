//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI
import CoreData

class SettingsViewModel: ObservableObject, ControllerServiceDelegate {
    @Published var selectedIndex: Int = 0
    let maxItems = 3  // Updated number of selectable items in settings
    var onDismiss: (() -> Void)?
    
    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        if !pressed { return }
        print("SettingsView: Controller pressed - \(pressed), action: \(action.rawValue)")
        
        switch action {
        case .up:
            selectedIndex = max(0, selectedIndex - 1)
        case .down:
            selectedIndex = min(maxItems - 1, selectedIndex + 1)
        case .a:
            // Handle selection
            break
        case .b:
            onDismiss?()
        default:
            break
        }
    }
}

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isDarkMode: Bool = false
    @State private var selectedColor: Color = .purple
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var dataController: CoreDataController
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("General Settings")) {
                    Toggle("Dark Mode", isOn: $themeManager.isDarkMode)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.selectedIndex == 0 ? Color.white : Color.clear, lineWidth: 2)
                        )
                    
                    Picker("Keyboard Color", selection: $themeManager.keyboardColor) {
                        ForEach(ThemeManager.KeyboardColor.allCases, id: \.self) { color in
                            Text(color.rawValue.capitalized)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(viewModel.selectedIndex == 1 ? Color.white : Color.clear, lineWidth: 2)
                    )
                    
                    NavigationLink("Manage ROMs") {
                        ManageRomsView().environmentObject(dataController)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(viewModel.selectedIndex == 2 ? Color.white : Color.clear, lineWidth: 2)
                    )
                }
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                .navigationTitle("Settings")
                .listStyle(GroupedListStyle())
            }
        }
        .onAppear {
            // Set the controller delegate to SettingsViewModel when view appears
            BluetoothControllerService.shared.delegate = viewModel
            viewModel.onDismiss = {
                presentationMode.wrappedValue.dismiss()
            }
            print("SettingsView: Setting controller delegate to SettingsViewModel")
        }
        .onDisappear {
            // Set the delegate back to HomeView's ViewModel when leaving
            if BluetoothControllerService.shared.delegate === viewModel {
                print("SettingsView: Setting controller delegate back to HomeView")
                HomeViewModel.shared.setAsDelegate()
            }
        }
    }
    
    
    
    
    struct ManageRomsView: View {
        @EnvironmentObject var dataController: CoreDataController
        @State private var newRomName: String = ""
        @State private var isLoading: Bool = false
        @StateObject private var viewModel = HomeViewModel.shared  // Use the shared HomeViewModel instance
        @State private var isPresented: Bool = false // To track sheet presentation
        @State private var roms: [Rom] = []
        
        var body: some View {
            NavigationView {
                VStack {
                    
                    // Loading overlay
                    if isLoading {
//                        ZStack {
//                            // Dimmed background
//                            Color.black.opacity(0.3)
//                                .edgesIgnoringSafeArea(.all) // Optional: If you want to dim the screen

                            // Spinner overlay
                            VStack(spacing: 15) {
                                
                                
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white)) // Adjust spinner color
                                    .scaleEffect(1.5) // Adjust size

                                Text("Loading...")
                                    .foregroundColor(.white) // Match text color to spinner
                                    .font(.headline) // Adjust font style
                            }
                            .padding(30)
                            .background(Color.black.opacity(0.8)) // Darker background for contrast
                            .cornerRadius(20) // Rounded corners
                            .shadow(radius: 10) // Optional shadow
                            .zIndex(1000) // Ensure it stays on top
                        }
//
//                    }
                    
                    List {
                        
                        ForEach(roms, id: \.self) { rom in
                            HStack {
                                Text(rom.name ?? "Unknown")
                                Spacer()
                                Button("Delete") {
                                    withAnimation {
                                        dataController.romManager.deleteRom(rom: rom)
                                        roms = dataController.romManager.fetchRoms()
                                    }
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle()) // Optional for styling
                    
                    
                    
                    
                }
                .navigationTitle("Manage ROMs")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            isPresented.toggle()
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .onAppear {
                    // Fetch ROMs when view appears
                    roms = dataController.romManager.fetchRoms()
                }
                .sheet(isPresented: $isPresented) {
                    DocumentPicker { url in
                        
                        // Use RomManager to handle adding the ROM
                        Task {
                            isLoading = true
                            await dataController.romManager.addRom( url: url)
                            withAnimation {
                                roms = dataController.romManager.fetchRoms()
                                isLoading = false
                            }
                        }
                        
                    }
                    .font(.custom("Orbitron-Black", size: 24))
                }
            }
        }
        
        
    }
    
    
    //struct CreateAccountView: View {
    //    @State private var username: String = ""
    //    @State private var email: String = ""
    //    @State private var password: String = ""
    //
    //    var body: some View {
    //        VStack {
    //            Form {
    //                Section(header: Text("Create Account")) {
    //                    TextField("Username", text: $username)
    //                    TextField("Email", text: $email)
    //                    SecureField("Password", text: $password)
    //                }
    //                Button("Create Account") {
    //                    createAccount()
    //                }
    //            }
    //            .navigationTitle("Create Account")
    //        }
    //    }
    //
    //    private func createAccount() {
    //        // Implement account creation logic
    //        // Example: Send the data to a backend or save locally
    //    }
    //}
    // WebView struct to handle opening URLs in a new view
    //struct WebView: View {
    //    let url: URL
    //
    //    var body: some View {
    //        WebViewRepresentable(url: url)
    //    }
    //}
    
    //// WebViewRepresentable to handle WKWebView
    //import WebKit
    //struct WebViewRepresentable: UIViewRepresentable {
    //    let url: URL
    //
    //    func makeUIView(context: Context) -> WKWebView {
    //        WKWebView()
    //    }
    //
    //    func updateUIView(_ uiView: WKWebView, context: Context) {
    //        uiView.load(URLRequest(url: url))
    //    }
    //}
    
    
    struct SettingsView_Previews: PreviewProvider {
        static var previews: some View {
            SettingsView()
        }
    }
}


