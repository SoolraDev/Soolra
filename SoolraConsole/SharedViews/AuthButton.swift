import PrivySDK
import SwiftUI

// Represents the different stages of the email authentication flow.
enum EmailAuthStep {
    case idle
    case sendingCode
    case codeSent
    case signingIn
}

struct AuthButton: View {
    // Observe the singleton instance of WalletManager
    @StateObject private var manager = walletManager

    // State for managing the UI presentation
    @State private var showingAuthOptions = false
    @State private var showingEmailSheet = false
    private var isErrorVisible: Bool {
        if manager.errorMessage != nil { return true } else { return false }
    }

    var body: some View {
        Group {
            if let errorMessage = manager.errorMessage {
                retryButton
                    .alert(
                        "Error: \(errorMessage)",
                        isPresented: .constant(isErrorVisible),
                        actions: {}
                    )
            } else if manager.isLoading {
                ProgressView("Please wait…")
            } else if let authState = manager.authState {
                button(for: authState)
            } else {
                // Placeholder before the initial auth state is loaded.
                ProgressView()
            }
        }
        .confirmationDialog(
            "How would you like to sign in?",
            isPresented: $showingAuthOptions,
            titleVisibility: .visible
        ) {
            Button("Sign in with Google") {
                Task { await manager.signInWithGoogle() }
            }
            Button("Sign in with Email") {
                showingEmailSheet = true
            }
        }
        .sheet(isPresented: $showingEmailSheet) {
            EmailAuthView(isPresented: $showingEmailSheet)
        }
    }

    @ViewBuilder
    private func button(for state: AuthState) -> some View {
        switch state {
        case .authenticated:
            Button("Sign out") {
                Task { await manager.signOut() }
            }
            .buttonStyle(.borderedProminent)
        default:
            Button("Sign in") {
                showingAuthOptions = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var retryButton: some View {
        Button("Retry") {
            showingAuthOptions = true
        }
    }
}
// MARK: - Email Authentication Subview

struct EmailAuthView: View {
    @Binding var isPresented: Bool

    @State private var email: String = ""
    @State private var otp: String = ""
    @State private var authStep: EmailAuthStep = .idle
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {

                TextField("Enter your email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(authStep != .idle)

                if authStep == .codeSent || authStep == .signingIn {
                    TextField("Enter the code", text: $otp)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: handleButtonTap) {
                    HStack {
                        if authStep == .sendingCode || authStep == .signingIn {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(buttonTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isButtonDisabled)
            }
            .padding()
            .navigationTitle("Sign in with Email")
            .navigationBarItems(
                leading: Button("Cancel") { isPresented = false }
            )
        }
    }

    // MARK: - Computed Properties

    private var buttonTitle: String {
        switch authStep {
        case .idle, .sendingCode:
            return "Get Code"
        case .codeSent, .signingIn:
            return "Continue"
        }
    }

    private var isButtonDisabled: Bool {
        if authStep == .sendingCode || authStep == .signingIn { return true }
        if authStep == .codeSent && otp.count < 4 { return true }  // Basic validation
        return email.isEmpty
    }

    // MARK: - Actions

    private func handleButtonTap() {
        errorMessage = nil
        if authStep == .codeSent {
            Task {
                await MainActor.run { authStep = .signingIn }
                await walletManager.verifySignInOtp(
                    otp: otp,
                    email: email
                )
                await MainActor.run {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
        } else {
            Task {
                await MainActor.run { authStep = .sendingCode }
                do {
                    try await walletManager.requestSignInOtp(email: email)
                    await MainActor.run {
                        withAnimation {
                            authStep = .codeSent
                        }
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    await MainActor.run { authStep = .idle }
                }
            }
        }
    }
}

#Preview {
    AuthButton()
}
