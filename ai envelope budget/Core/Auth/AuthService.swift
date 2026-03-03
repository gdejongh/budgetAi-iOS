//
//  AuthService.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class AuthService {
    // MARK: - State

    var isAuthenticated = false
    var userEmail: String?
    var userId: String?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let api: APIClient
    private let keychain: KeychainManager

    // MARK: - Init

    init(api: APIClient = .shared, keychain: KeychainManager = .shared) {
        self.api = api
        self.keychain = keychain

        // Restore session from Keychain
        if keychain.hasTokens {
            self.isAuthenticated = true
            self.userEmail = keychain.get(.email)
            self.userId = keychain.get(.userId)
        }

        // Wire up auth failure callback (force logout on expired refresh token)
        let service = self
        Task {
            await api.setOnAuthFailure {
                Task { @MainActor in
                    service.handleAuthFailure()
                }
            }
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: AuthResponse = try await api.request(
                .post,
                path: "/api/auth/login",
                body: LoginRequest(email: email, password: password),
                authenticated: false
            )

            keychain.saveAuthResponse(response)
            isAuthenticated = true
            userEmail = response.email
            userId = response.userId
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
        }

        isLoading = false
    }

    // MARK: - Register

    func register(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // Create account
            let _: AppUserResponse = try await api.request(
                .post,
                path: "/api/users",
                body: AppUserRequest(email: email, password: password),
                authenticated: false
            )

            // Auto-login after successful registration
            let authResponse: AuthResponse = try await api.request(
                .post,
                path: "/api/auth/login",
                body: LoginRequest(email: email, password: password),
                authenticated: false
            )

            keychain.saveAuthResponse(authResponse)
            isAuthenticated = true
            userEmail = authResponse.email
            userId = authResponse.userId
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Registration failed. Please try again."
        }

        isLoading = false
    }

    // MARK: - Logout

    func logout() async {
        // Fire-and-forget API call — we clear local state regardless
        try? await api.requestVoid(.post, path: "/api/auth/logout")

        keychain.clearAll()
        isAuthenticated = false
        userEmail = nil
        userId = nil
        errorMessage = nil
    }

    // MARK: - Clear Error

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private

    private func handleAuthFailure() {
        keychain.clearAll()
        isAuthenticated = false
        userEmail = nil
        userId = nil
    }
}

// MARK: - APIClient Auth Failure Extension

extension APIClient {
    func setOnAuthFailure(_ handler: @escaping @Sendable () -> Void) {
        self.onAuthFailure = handler
    }
}
