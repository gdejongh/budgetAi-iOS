//
//  AiAdviceCardView.swift
//  ai envelope budget
//
//  Created on 3/4/26.
//

import SwiftUI

struct AiAdviceCardView: View {
    @Environment(AiAdviceService.self) private var aiAdviceService

    var body: some View {
        Group {
            if aiAdviceService.isLoading {
                loadingContent
            } else if let advice = aiAdviceService.advice {
                adviceContent(advice)
            } else if aiAdviceService.isRateLimited {
                rateLimitedContent
            } else if let error = aiAdviceService.errorMessage {
                errorContent(error)
            } else {
                emptyContent
            }
        }
    }

    // MARK: - Empty State (No advice loaded yet)

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: AppDesign.paddingSm + 4) {
            Label {
                Text("AI Financial Insights")
                    .font(.appHeadline)
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundStyle(LinearGradient.brand)
            }

            Text("Get personalized advice based on your accounts, envelopes, and spending patterns.")
                .font(.appSubheadline)
                .foregroundStyle(Color.textSecondary)

            Button {
                Task { await aiAdviceService.fetchAdvice() }
            } label: {
                Text("Get AI Advice")
            }
            .buttonStyle(GradientButtonStyle())
        }
        .padding(.vertical, 4)
    }

    // MARK: - Loading State

    private var loadingContent: some View {
        VStack(spacing: AppDesign.paddingMd) {
            LoadingDots()

            Text("Analyzing your finances…")
                .font(.appSubheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.paddingMd)
    }

    // MARK: - Advice Loaded

    private func adviceContent(_ advice: AiAdviceResponse) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.paddingSm + 4) {
            // Header
            Label {
                Text("AI Financial Insights")
                    .font(.appHeadline)
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundStyle(LinearGradient.brand)
            }

            // Markdown-rendered advice text
            Text(advice.parsedMarkdown)
                .font(.appSubheadline)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // Footer: metadata + refresh button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let generatedAt = advice.formattedGeneratedAt {
                        Text("Generated \(generatedAt)")
                            .font(.caption2)
                            .foregroundStyle(Color.textMuted)
                    }

                    Text(advice.refreshesRemainingText)
                        .font(.caption2)
                        .foregroundStyle(advice.refreshesRemaining > 0 ? Color.textSecondary : Color.warning)
                }

                Spacer()

                Button {
                    Task {
                        await aiAdviceService.clearCache()
                        await aiAdviceService.fetchAdvice()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderless)
                .disabled(advice.refreshesRemaining == 0 || aiAdviceService.isRateLimited)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Rate Limited State

    private var rateLimitedContent: some View {
        VStack(alignment: .leading, spacing: AppDesign.paddingSm) {
            Label {
                Text("AI Financial Insights")
                    .font(.appHeadline)
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundStyle(LinearGradient.brand)
            }

            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(Color.warning)

                Text("Daily advice limit reached. Try again tomorrow.")
                    .font(.appSubheadline)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Error State

    private func errorContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.paddingSm + 4) {
            Label {
                Text("AI Financial Insights")
                    .font(.appHeadline)
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundStyle(LinearGradient.brand)
            }

            ErrorBannerView(message: message) {
                await aiAdviceService.fetchAdvice()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Empty") {
    List {
        Section {
            AiAdviceCardView()
        }
    }
    .listStyle(.insetGrouped)
    .environment(AiAdviceService())
}
