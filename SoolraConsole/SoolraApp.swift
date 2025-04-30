//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import AVFoundation
import SwiftUI

public class AudioSessionManager: ObservableObject {
    private var audioSessionObserver: Any?
    private var routeChangeObserver: Any?
    private var interruptionObserver: Any?
    @Published public private(set) var isAudioSessionActive = true
    public var onAudioSessionStateChange: ((Bool) -> Void)?
    @StateObject private var themeManager = ThemeManager()

    public init() {
        setUpAudioSession()
        addObservers()
    }

    private func setUpAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setPreferredIOBufferDuration(0.005) // 5ms buffer for low latency
            try audioSession.setPreferredSampleRate(44100)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            isAudioSessionActive = true
            onAudioSessionStateChange?(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            isAudioSessionActive = false
            onAudioSessionStateChange?(false)
        }
    }

    private func addObservers() {
        audioSessionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setUpAudioSession()
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
        
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
    }
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt else {
            return
        }
        
        let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        print("🔊 Audio route changed with reason: \(reason)")
        
        // Handle route change based on reason
        switch reason {
        case .newDeviceAvailable:
            // New device was connected
            print("🔊 New audio device available")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.reactivateAudioSession()
            }
            
        case .oldDeviceUnavailable:
            // Device was disconnected
            print("🔊 Audio device disconnected")
            isAudioSessionActive = false
            onAudioSessionStateChange?(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.reactivateAudioSession()
            }
            
        case .categoryChange:
            // Category changed (e.g., when another app takes over audio)
            print("🔊 Audio category changed")
            isAudioSessionActive = false
            onAudioSessionStateChange?(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.reactivateAudioSession()
            }
            
        case .override:
            // Audio was overridden by another app
            print("🔊 Audio overridden by another app")
            isAudioSessionActive = false
            onAudioSessionStateChange?(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.reactivateAudioSession()
            }
            
        case .routeConfigurationChange:
            // Route configuration changed but may still be usable
            print("🔊 Audio route configuration changed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.reactivateAudioSession()
            }
            
        default:
            print("🔊 Unhandled audio route change: \(reason)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.reactivateAudioSession()
            }
        }
    }
    
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt else {
            return
        }
        
        let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        
        switch type {
        case .began:
            print("🔊 Audio session interrupted")
            isAudioSessionActive = false
            onAudioSessionStateChange?(false)
            
        case .ended:
            print("🎵 Audio session interruption ended")
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) {
                print("🔊 Audio session interruption ended - attempting to resume")
                // Add a small delay to ensure the audio system is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.reactivateAudioSession()
                }
            }
            
        default:
            break
        }
    }
    
    private func reactivateAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setPreferredIOBufferDuration(0.005)
            try audioSession.setPreferredSampleRate(44100)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            isAudioSessionActive = true
            onAudioSessionStateChange?(true)
        } catch {
            print("Failed to reactivate audio session: \(error)")
            // Try one more time after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                do {
                    let audioSession = AVAudioSession.sharedInstance()
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    self?.isAudioSessionActive = true
                    self?.onAudioSessionStateChange?(true)
                } catch {
                    print("Failed to reactivate audio session on retry: \(error)")
                    self?.isAudioSessionActive = false
                    self?.onAudioSessionStateChange?(false)
                }
            }
        }
    }

    deinit {
        if let observer = audioSessionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

@main
struct SoolraApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var dataController = CoreDataController()
    @StateObject private var audioSessionManager = AudioSessionManager()
    @StateObject private var metalManager: MetalManager
    @StateObject private var consoleManager: ConsoleCoreManager
    @State private var isShowingSplash = true
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var initializationError: Error?

    init() {
        // Initialize Metal device first and handle potential errors
        do {
            let metal = try MetalManager()
            _metalManager = StateObject(wrappedValue: metal)
            
            // Initialize console manager with metal manager
            let console = try ConsoleCoreManager(metalManager: metal)
            _consoleManager = StateObject(wrappedValue: console)
            
            
        } catch {
            // If initialization fails, we need to provide default values
            // but we'll store the error to show it to the user
            print("❌ Failed to initialize Metal: \(error)")
            let metal = try! MetalManager() // This will crash, but it's better than having invalid state
            _metalManager = StateObject(wrappedValue: metal)
            let console = try! ConsoleCoreManager(metalManager: metal)
            _consoleManager = StateObject(wrappedValue: console)
            initializationError = error
        }

        // Configure UI appearance
        let appearance = UINavigationBarAppearance()
        appearance.titleTextAttributes = [.font: UIFont(name: "Orbitron-Black", size: 24)!]
        appearance.largeTitleTextAttributes = [.font: UIFont(name: "Orbitron-Black", size: 34)!]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = .black
        appearance.backgroundColor = .none
        appearance.configureWithOpaqueBackground()
    }

    var body: some Scene {
        WindowGroup {
            if let error = initializationError {
                // Show error view if initialization failed
                ErrorView(error: error)
                    .environmentObject(themeManager)
            } else if isShowingSplash {
                SplashView(isShowingSplash: $isShowingSplash)
                    .environmentObject(themeManager)
                    .environmentObject(dataController)
                    .environmentObject(consoleManager)
                    .onAppear {
                        consoleManager.connectAudioSessionManager(audioSessionManager)
                        print("🚀 SplashView loading bundled ROMs")
                        Task {
                            await dataController.romManager.initBundledRoms()
                        }
                    }
            } else {
                HomeView()
                    .environmentObject(themeManager)
                    .environmentObject(dataController)
                    .environmentObject(consoleManager)
                    .environmentObject(metalManager)
                    .onAppear {
                        consoleManager.connectAudioSessionManager(audioSessionManager)
                    }
            }
        }
    }
}

// Add a simple error view to show initialization errors
struct ErrorView: View {
    let error: Error
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Initialization Error")
                .font(.title)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .padding()
            
            Text("Please restart the application. If the problem persists, contact support.")
                .font(.callout)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
}

extension UIView {
    func snapshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        self.layer.render(in: context)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
