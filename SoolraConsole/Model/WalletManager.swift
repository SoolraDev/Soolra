import PrivySDK
import SwiftUI  // Or Combine, for ObservableObject

extension AuthState: @retroactive Equatable {
    public static func == (lhs: PrivySDK.AuthState, rhs: PrivySDK.AuthState)
        -> Bool
    {
        // Use a switch on a tuple to compare all possible combinations
        switch (lhs, rhs) {
        // Case 1: Both are .notReady. They are equal.
        case (.notReady, .notReady):
            return true

        // Case 2: Both are .unauthenticated. They are equal.
        case (.unauthenticated, .unauthenticated):
            return true

        // Case 3: Both are .authenticatedUnverified. Since the context has no properties, they are equal.
        case (.authenticatedUnverified, .authenticatedUnverified):
            return true

        // Case 4: Both are .authenticated. Compare them by the user's ID.
        case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
            return lhsUser.id == rhsUser.id

        // Default: If none of the above patterns match, the states are not equal.
        default:
            return false
        }
    }
}

let USDTAddress = "0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2"
let USDCAddress = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
let SOOLAddress = ""  // TODO: update contract
let chainId = 8453

@MainActor
public class WalletManager: ObservableObject {
    // MARK: - Published Properties

    @Published public var authState: AuthState?
    @Published public var privyUser: PrivyUser?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var balances: [String: String] = [
        "usdc": "0.0", "usdt": "0.0",
    ]

    public let privyClient: Privy

    init() {
        let privyConfig = PrivyConfig(
            appId: Configuration.privyAppId,
            appClientId: Configuration.privyClientId,
            loggingConfig: .init(logLevel: .verbose)
        )
        self.privyClient = PrivySdk.initialize(config: privyConfig)

        // Initial check for auth state
        Task {
            await checkInitialAuthState()
        }
    }

    /// The single point of truth for updating all app services after authentication.
    private func onUserAuthenticated() async {
        guard let user = self.privyUser else { return }

        // 1. Get the JWT for API calls
        let accessToken = try? await user.getAccessToken()

        // 2. Update the shared AuthManager for the ApiClient
        AuthManager.shared.currentPrivyId = user.id
        AuthManager.shared.currentJwt = accessToken

        // 3. Notify the EngagementTracker of the new user
        globalEngagementTracker.setPrivyId(user.id)

        print("✅ WalletManager: Auth state updated for user \(user.id).")
    }

    /// The single point of truth for clearing state after logout.
    private func onUserSignedOut() {
        // 1. Clear the shared AuthManager
        AuthManager.shared.clear()

        // 2. Notify the EngagementTracker that the user is gone
        globalEngagementTracker.setPrivyId(nil as String?)

        print("🔴 WalletManager: Auth state cleared.")
    }

    // MARK: - Public Auth Methods

    public func checkInitialAuthState() async {
        self.isLoading = true
        self.authState = await self.privyClient.getAuthState()
        self.privyUser = await self.privyClient.getUser()

        if self.privyUser != nil {
            // User is already logged in, update services
            await onUserAuthenticated()
        }

        self.isLoading = false
    }

    public func signInWithGoogle() async {
        self.isLoading = true
        self.errorMessage = nil
        do {
            let user = try await self.privyClient.oAuth.login(with: .google)
            self.privyUser = user
            self.authState = .authenticated(user)

            if user.embeddedEthereumWallets.isEmpty == true {
                try await self.createWallet()
            }

            // User is now logged in, update services
            await onUserAuthenticated()

        } catch {
            self.errorMessage = error.localizedDescription
        }
        self.isLoading = false
    }

    public func requestSignInOtp(email: String) async throws {
        // This method doesn't change the global state, so it can remain a simple throwing function
        // for the EmailAuthView to handle locally.
        try await self.privyClient.email.sendCode(to: email)
    }

    public func verifySignInOtp(otp: String, email: String) async {
        self.isLoading = true
        self.errorMessage = nil
        do {
            let user = try await self.privyClient.email.loginWithCode(
                otp,
                sentTo: email
            )
            self.privyUser = user
            self.authState = .authenticated(user)

            if user.embeddedEthereumWallets.isEmpty == true {
                try await self.createWallet()
            }

            // User is now logged in, update services
            await onUserAuthenticated()

        } catch {
            self.errorMessage = error.localizedDescription
        }
        self.isLoading = false
    }

    public func signOut() async {
        self.isLoading = true
        await self.privyUser?.logout()
        self.privyUser = nil
        self.authState = await self.privyClient.getAuthState()

        // User is now signed out, clear services
        onUserSignedOut()

        self.isLoading = false
    }

    public func getAccessToken() async -> String? {
        // This is now mainly used internally by the onUserAuthenticated method
        return try? await self.privyUser?.getAccessToken()
    }

    public func getBalances() async {
        let defaultBalances = ["usdc": "0.0", "usdt": "0.0"]

        // The ApiClient will now get the token from AuthManager, so this function
        // no longer needs to fetch it directly. We just need the user ID.
        guard let userId = self.privyUser?.id else {
            print("Error: User ID is nil.")
            self.balances = defaultBalances
            return
        }

        let address = self.getAddress() ?? ""
        let urlString =
            "\(Configuration.soolraBackendURL)/v1/users/\(userId)/balance/\(address)"
        guard let url = URL(string: urlString) else {
            self.balances = defaultBalances
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // The ApiClient and its AuthManager handle headers now.
        // For direct calls like this, we retrieve from AuthManager.
        if let headers = AuthManager.shared.getAuthHeaders() {
            request.allHTTPHeaderFields = headers
        } else {
            print("Error: Could not get auth headers for getBalances.")
            self.balances = defaultBalances
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )
            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else {
                print(
                    "Error: Received non-200 status from getBalances: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
                )
                self.balances = defaultBalances
                return
            }
            let balances = try JSONDecoder().decode(
                [String: String].self,
                from: data
            )
            self.balances = balances
        } catch {
            print(
                "An error occurred while fetching balances: \(error.localizedDescription)"
            )
            self.balances = defaultBalances
        }
    }

    // (rest of the wallet methods like createWallet, signTransaction, etc.)
    func createWallet() async throws -> EmbeddedEthereumWallet? {
        return try await self.privyUser?.createEthereumWallet()
    }

    func getAddress() -> String? {
        return self.privyUser?.embeddedEthereumWallets.first?.address
    }

    func signTransaction(transaction: EthereumRpcRequest.UnsignedEthTransaction)
        async throws -> String?
    {
        return try await self.privyUser?.embeddedEthereumWallets.first?.provider
            .request(.ethSignTransaction(transaction: transaction))
    }

    func sendTransaction(transaction: EthereumRpcRequest.UnsignedEthTransaction)
        async throws -> String?
    {
        return try await self.privyUser?.embeddedEthereumWallets.first?.provider
            .request(.ethSendTransaction(transaction: transaction))
    }

    func signMessage(message: String) async throws -> String? {
        guard
            let address = self.privyUser?.embeddedEthereumWallets.first?.address
        else {
            return nil
        }

        return try await self.privyUser?.embeddedEthereumWallets.first?.provider
            .request(.personalSign(message: message, address: address))
    }

    func signTypedData(typedData: EthereumRpcRequest.EIP712TypedData)
        async throws -> String?
    {
        guard
            let address = self.privyUser?.embeddedEthereumWallets.first?.address
        else {
            return nil
        }

        return try await self.privyUser?.embeddedEthereumWallets.first?.provider
            .request(
                .ethSignTypedDataV4(address: address, typedData: typedData)
            )
    }
}

@MainActor public let walletManager = WalletManager()
