//
//  WalletManager.swift
//  SOOLRA
//
//  Created by Michael Essiet on 29/10/2025.
//

import PrivySDK
import Web3

public class WalletManager {
    public let privyClient: Privy
    public var privyUser: PrivyUser?

    init() {
        let privyConfig = PrivyConfig(
            appId: "cmhce45oa003jl40b67t2vutc",
            appClientId: "client-WY6STFdmgPu6LfcrVXcaSA6XkDLHC59UeaxwAY2aautjw",
            loggingConfig: .init(
                logLevel: .verbose
            )
        )
        self.privyClient = PrivySdk.initialize(config: privyConfig)
    }

    func signInWithGoogle() async throws -> PrivyUser {
        self.privyUser = try await self.privyClient.oAuth.login(with: .google)
        return self.privyUser!
    }

    func createWallet() async throws -> EmbeddedEthereumWallet? {
        return try await self.privyUser?.createEthereumWallet()
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
