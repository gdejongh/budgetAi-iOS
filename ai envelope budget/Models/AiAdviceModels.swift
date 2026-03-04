//
//  AiAdviceModels.swift
//  ai envelope budget
//
//  Created on 3/4/26.
//

import Foundation

// MARK: - Response DTO

nonisolated struct AiAdviceResponse: Codable, Sendable {
    let advice: String
    let generatedAt: String?
    let cachedUntil: String?
    let refreshesRemaining: Int

    // MARK: - Computed Properties

    /// Parses the advice Markdown string into an AttributedString for native rendering.
    var parsedMarkdown: AttributedString {
        (try? AttributedString(markdown: advice, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(advice)
    }

    /// Human-readable "Generated" timestamp.
    var formattedGeneratedAt: String? {
        guard let generatedAt else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none

        if let date = isoFormatter.date(from: generatedAt) {
            return displayFormatter.string(from: date)
        }
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: generatedAt) {
            return displayFormatter.string(from: date)
        }
        return generatedAt
    }

    /// Text describing remaining refreshes, e.g. "2 of 3 refreshes remaining".
    var refreshesRemainingText: String {
        "\(refreshesRemaining) of 3 refresh\(refreshesRemaining == 1 ? "" : "es") remaining"
    }
}
