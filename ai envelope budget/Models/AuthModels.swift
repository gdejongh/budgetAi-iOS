//
//  AuthModels.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import Foundation

// MARK: - Request DTOs

nonisolated struct LoginRequest: Codable, Sendable {
    let email: String
    let password: String
}

nonisolated struct RefreshRequest: Codable, Sendable {
    let refreshToken: String
}

nonisolated struct AppUserRequest: Codable, Sendable {
    let email: String
    let password: String
}

// MARK: - Response DTOs

nonisolated struct AuthResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let email: String
}

nonisolated struct AppUserResponse: Codable, Sendable {
    let id: String?
    let email: String
    let createdAt: String?
}

// MARK: - Error Response

nonisolated struct APIErrorResponse: Codable, Sendable {
    let status: Int?
    let error: String?
    let message: String?
    let fieldErrors: [String: String]?
}
