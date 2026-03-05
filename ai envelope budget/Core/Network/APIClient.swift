//
//  APIClient.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import Foundation

// MARK: - API Error

nonisolated enum APIError: LocalizedError {
    case unauthorized(String?)
    case forbidden(String?)
    case notFound(String?)
    case validation(String?)
    case conflict(String?)
    case rateLimited(String?)
    case serverError(String?)
    case network(Error)
    case decodingError(Error)
    case unknown(Int, String?)

    var errorDescription: String? {
        switch self {
        case .unauthorized(let msg): return msg ?? "Invalid or expired credentials."
        case .forbidden(let msg): return msg ?? "Access denied."
        case .notFound(let msg): return msg ?? "Resource not found."
        case .validation(let msg): return msg ?? "Invalid input."
        case .conflict(let msg): return msg ?? "A resource with that name already exists."
        case .rateLimited(let msg): return msg ?? "Rate limit exceeded. Please try again later."
        case .serverError(let msg): return msg ?? "An unexpected error occurred."
        case .network(let error): return error.localizedDescription
        case .decodingError(let error): return "Failed to process response: \(error.localizedDescription)"
        case .unknown(let code, let msg): return msg ?? "Unexpected error (HTTP \(code))."
        }
    }
}

// MARK: - HTTP Method

nonisolated enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - API Client

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Tracks an in-flight refresh task so concurrent 401s coalesce into a single refresh.
    private var refreshTask: Task<AuthResponse, Error>?

    /// Callback for when the refresh token itself is invalid (force logout).
    var onAuthFailure: (@Sendable () -> Void)?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.baseURL = AppEnvironment.current.apiBaseURL
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Public Request Methods

    /// Perform a request that returns a decoded response body.
    func request<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        let data = try await performRequest(
            method, path: path, body: body,
            queryItems: queryItems, authenticated: authenticated
        )
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// Perform a request that expects no response body (e.g., 204).
    func requestVoid(
        _ method: HTTPMethod,
        path: String,
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil,
        authenticated: Bool = true
    ) async throws {
        _ = try await performRequest(
            method, path: path, body: body,
            queryItems: queryItems, authenticated: authenticated
        )
    }

    // MARK: - Core Request Logic

    private func performRequest(
        _ method: HTTPMethod,
        path: String,
        body: (any Encodable)?,
        queryItems: [URLQueryItem]?,
        authenticated: Bool,
        isRetry: Bool = false
    ) async throws -> Data {
        var urlRequest = try buildRequest(method, path: path, body: body, queryItems: queryItems, authenticated: authenticated)

        let (data, response) = try await execute(urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(0, "Invalid response")
        }

        let statusCode = httpResponse.statusCode

        // Success range
        if (200...299).contains(statusCode) {
            return data
        }

        // Parse error body
        let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data)
        let message = errorResponse?.message
            ?? errorResponse?.fieldErrors?.values.first

        // Handle 401 with token refresh (only for authenticated requests, and only once)
        if statusCode == 401, authenticated, !isRetry {
            do {
                try await refreshAccessToken()
                // Rebuild the request with the new token and retry once
                urlRequest = try buildRequest(method, path: path, body: body, queryItems: queryItems, authenticated: true)
                let (retryData, retryResponse) = try await execute(urlRequest)

                guard let retryHttp = retryResponse as? HTTPURLResponse,
                      (200...299).contains(retryHttp.statusCode) else {
                    // Still failing after refresh — force logout
                    onAuthFailure?()
                    throw mapError(statusCode: statusCode, message: message)
                }
                return retryData
            } catch is APIError {
                // Refresh itself failed — force logout
                onAuthFailure?()
                throw APIError.unauthorized(message)
            }
        }

        throw mapError(statusCode: statusCode, message: message)
    }

    private func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.network(error)
        }
    }

    // MARK: - Request Building

    private func buildRequest(
        _ method: HTTPMethod,
        path: String,
        body: (any Encodable)?,
        queryItems: [URLQueryItem]?,
        authenticated: Bool
    ) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.unknown(0, "Invalid URL: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated, let token = KeychainManager.shared.get(.accessToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    // MARK: - Token Refresh (Coalesced)

    private func refreshAccessToken() async throws {
        // If a refresh is already in flight, await that one instead of spawning another
        if let existing = refreshTask {
            _ = try await existing.value
            return
        }

        guard let refreshToken = KeychainManager.shared.get(.refreshToken) else {
            throw APIError.unauthorized("No refresh token available")
        }

        let task = Task<AuthResponse, Error> {
            let body = RefreshRequest(refreshToken: refreshToken)
            let data = try encoder.encode(body)

            var request = URLRequest(url: baseURL.appendingPathComponent("/api/auth/refresh"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data

            let (responseData, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.unauthorized("Token refresh failed")
            }

            return try decoder.decode(AuthResponse.self, from: responseData)
        }

        refreshTask = task

        do {
            let authResponse = try await task.value
            KeychainManager.shared.saveAuthResponse(authResponse)
            refreshTask = nil
        } catch {
            refreshTask = nil
            throw error
        }
    }

    // MARK: - Error Mapping

    /// Cancels any in-flight token refresh task. Called on logout to prevent
    /// a stale refresh from overwriting a new user's tokens.
    func cancelRefreshTask() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func mapError(statusCode: Int, message: String?) -> APIError {
        switch statusCode {
        case 400: return .validation(message)
        case 401: return .unauthorized(message)
        case 403: return .forbidden(message)
        case 404: return .notFound(message)
        case 409: return .conflict(message)
        case 429: return .rateLimited(message)
        case 500...599: return .serverError(message)
        default: return .unknown(statusCode, message)
        }
    }
}
