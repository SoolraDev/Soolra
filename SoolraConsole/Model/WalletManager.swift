import PrivySDK
import SwiftUI // Or Combine, for ObservableObject

extension AuthState: @retroactive Equatable {
    public static func == (lhs: PrivySDK.AuthState, rhs: PrivySDK.AuthState) -> Bool {
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
        case let (.authenticated(lhsUser), .authenticated(rhsUser)):
            return lhsUser.id == rhsUser.id

        // Default: If none of the above patterns match, the states are not equal.
        default:
            return false
        }
    }
}

@MainActor
public class WalletManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var authState: AuthState?
    @Published public var privyUser: PrivyUser?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    public let privyClient: Privy

    init() {
        let privyConfig = PrivyConfig(
            appId: "cmhce45oa003jl40b67t2vutc",
            appClientId: "client-WY6STFdmgPu6LfcrVXcaSA6XkDLHC59UeaxwAY2aautjw",
            loggingConfig: .init(logLevel: .verbose)
        )
        self.privyClient = PrivySdk.initialize(config: privyConfig)
        
        // Initial check for auth state
        Task {
            await checkInitialAuthState()
        }
    }
    
    // MARK: - Public Auth Methods

    public func checkInitialAuthState() async {
        self.isLoading = true
        self.authState = await self.privyClient.getAuthState()
        self.privyUser = await self.privyClient.getUser()
        self.isLoading = false
    }

    public func signInWithGoogle() async {
        self.isLoading = true
        self.errorMessage = nil
        do {
            self.privyUser = try await self.privyClient.oAuth.login(with: .google)
            self.authState = .authenticated(self.privyUser!)
            if self.privyUser?.embeddedEthereumWallets.isEmpty == true {
                try await self.createWallet()
            }
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
            self.privyUser = try await self.privyClient.email.loginWithCode(otp, sentTo: email)
            self.authState = .authenticated(self.privyUser!)
            if self.privyUser?.embeddedEthereumWallets.isEmpty == true {
                try await self.createWallet()
            }
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
        self.isLoading = false
    }

    // ... (rest of your wallet methods like createWallet, signTransaction, etc.)
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
