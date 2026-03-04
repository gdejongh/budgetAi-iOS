//
//  AiAdviceService.swift
//  ai envelope budget
//
//  Created on 3/4/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class AiAdviceService {
    // MARK: - State

    var advice: AiAdviceResponse?
    var isLoading = false
    var errorMessage: String?
    var isRateLimited = false

    // MARK: - Dependencies

    private let api: APIClient

    // MARK: - Init

    init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: - Fetch Advice

    /// Requests AI financial advice from the backend.
    /// Uses cached response on the server side if available (24h TTL).
    func fetchAdvice() async {
        isLoading = true
        errorMessage = nil
        isRateLimited = false

        do {
            let response: AiAdviceResponse = try await api.request(
                .post,
                path: "/api/ai/advice",
                authenticated: true
            )
            advice = response
        } catch let error as APIError {
            if case .rateLimited = error {
                isRateLimited = true
                errorMessage = "Daily advice limit reached. Try again tomorrow."
            } else {
                errorMessage = error.errorDescription
            }
        } catch {
            errorMessage = "Failed to load AI advice."
        }

        isLoading = false
    }

    // MARK: - Clear Cache

    /// Clears the server-side cached advice so the next fetch generates fresh advice.
    /// Does not affect the rate limit counter.
    func clearCache() async {
        do {
            try await api.requestVoid(
                .delete,
                path: "/api/ai/advice/cache",
                authenticated: true
            )
            advice = nil
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to clear advice cache."
        }
    }
}
