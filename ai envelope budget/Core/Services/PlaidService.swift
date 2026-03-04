//
//  PlaidService.swift
//  ai envelope budget
//
//  Created on 3/4/26.
//

import Foundation
import LinkKit
import Observation
import UIKit

@Observable
@MainActor
final class PlaidService {
    // MARK: - State

    var plaidItems: [PlaidItemResponse] = []
    var isLoading = false
    var isLinking = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let api: APIClient

    // MARK: - Private State

    private var linkHandler: Handler?

    // MARK: - Init

    init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: - Create Link Token

    /// Requests a new Plaid Link token from the backend.
    func createLinkToken() async throws -> String {
        let response: LinkTokenResponse = try await api.request(
            .post,
            path: "/api/plaid/link-token",
            authenticated: true
        )
        return response.linkToken
    }

    // MARK: - Exchange Token

    /// Exchanges the public token with account mapping. Returns created/linked accounts.
    func exchangeToken(_ request: ExchangeTokenRequest) async throws -> [BankAccountResponse] {
        let accounts: [BankAccountResponse] = try await api.request(
            .post,
            path: "/api/plaid/exchange-token",
            body: request,
            authenticated: true
        )
        return accounts
    }

    // MARK: - Fetch Plaid Items

    func fetchPlaidItems() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [PlaidItemResponse] = try await api.request(
                .get,
                path: "/api/plaid/items",
                authenticated: true
            )
            plaidItems = response
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to load Plaid connections."
        }

        isLoading = false
    }

    // MARK: - Unlink Item

    func unlinkItem(_ id: String) async -> Bool {
        errorMessage = nil

        do {
            try await api.requestVoid(
                .delete,
                path: "/api/plaid/items/\(id)",
                authenticated: true
            )
            plaidItems.removeAll { $0.id == id }
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to unlink connection."
            return false
        }
    }

    // MARK: - Sync All

    func syncAll() async -> SyncResultResponse? {
        errorMessage = nil

        do {
            let result: SyncResultResponse = try await api.request(
                .post,
                path: "/api/plaid/sync",
                authenticated: true
            )
            return result
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return nil
        } catch {
            errorMessage = "Failed to sync accounts."
            return nil
        }
    }

    // MARK: - Open Plaid Link

    /// Opens the native Plaid Link SDK flow. Returns the link result on success.
    /// Throws if the user dismisses or an error occurs.
    func openPlaidLink() async throws -> PlaidLinkResult {
        isLinking = true
        errorMessage = nil

        do {
            let linkToken = try await createLinkToken()
            let result = try await presentPlaidLink(token: linkToken)
            isLinking = false
            return result
        } catch {
            isLinking = false
            if error.localizedDescription != "PLAID_LINK_DISMISSED" {
                errorMessage = error.localizedDescription
            }
            throw error
        }
    }

    // MARK: - Private: Present Plaid Link SDK

    private func presentPlaidLink(token: String) async throws -> PlaidLinkResult {
        try await withCheckedThrowingContinuation { continuation in
            var config = LinkTokenConfiguration(token: token) { success in
                let accounts = success.metadata.accounts.map { account in
                    PlaidLinkAccount(
                        id: account.id,
                        name: account.name,
                        mask: account.mask,
                        type: Self.plaidAccountType(from: account.subtype),
                        subtype: account.subtype.description
                    )
                }

                let result = PlaidLinkResult(
                    publicToken: success.publicToken,
                    institutionName: success.metadata.institution.name,
                    institutionId: success.metadata.institution.id,
                    accounts: accounts
                )
                continuation.resume(returning: result)
            }

            config.onExit = { exit in
                if let error = exit.error {
                    continuation.resume(throwing: PlaidLinkError.sdkError(
                        error.displayMessage ?? error.errorMessage
                    ))
                } else {
                    continuation.resume(throwing: PlaidLinkError.dismissed)
                }
            }

            let createResult = Plaid.create(config)
            switch createResult {
            case .success(let handler):
                self.linkHandler = handler

                // Get the topmost view controller to present from
                guard let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene }).first,
                    let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                else {
                    continuation.resume(throwing: PlaidLinkError.noPresentingViewController)
                    return
                }

                // Find the topmost presented VC
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }

                handler.open(presentUsing: .viewController(topVC))

            case .failure(let error):
                continuation.resume(throwing: PlaidLinkError.configurationError(error.localizedDescription))
            }
        }
    }

    /// Clean up handler when done
    func destroyLink() {
        linkHandler = nil
    }

    // MARK: - Helpers

    /// Maps a LinkKit AccountSubtype to a Plaid account type string
    /// matching the backend's expected values (depository, credit, loan, etc.)
    private static func plaidAccountType(from subtype: LinkKit.AccountSubtype) -> String {
        switch subtype {
        case .depository:
            return "depository"
        case .credit:
            return "credit"
        case .loan:
            return "loan"
        case .investment:
            return "investment"
        case .other:
            return "other"
        case .unknown(let type, _):
            return type
        }
    }
}

// MARK: - Plaid Link Error

nonisolated enum PlaidLinkError: LocalizedError, Sendable {
    case dismissed
    case sdkError(String)
    case configurationError(String)
    case noPresentingViewController

    var errorDescription: String? {
        switch self {
        case .dismissed:
            return "PLAID_LINK_DISMISSED"
        case .sdkError(let message):
            return message
        case .configurationError(let message):
            return "Plaid configuration error: \(message)"
        case .noPresentingViewController:
            return "Unable to present Plaid Link."
        }
    }
}
