//
//  DashboardView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct DashboardView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        ZStack {
            Color.bgPrimary
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.success)
                        .shadow(color: .success.opacity(0.4), radius: 16, x: 0, y: 4)

                    GradientText("Welcome!", font: .system(size: 28, weight: .bold))

                    if let email = authService.userEmail {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                // Placeholder content
                VStack(spacing: 16) {
                    infoCard(
                        icon: "building.columns.fill",
                        title: "Accounts",
                        subtitle: "Coming soon"
                    )
                    infoCard(
                        icon: "envelope.open.fill",
                        title: "Envelopes",
                        subtitle: "Coming soon"
                    )
                    infoCard(
                        icon: "arrow.left.arrow.right",
                        title: "Transactions",
                        subtitle: "Coming soon"
                    )
                }
                .padding(.horizontal, AppDesign.paddingLg)

                Spacer()

                // Logout button
                Button {
                    Task {
                        await authService.logout()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.danger)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                            .fill(Color.danger.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                                    .stroke(Color.danger.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(.bottom, 32)
            }
            .padding(.top, 60)
        }
    }

    private func infoCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(LinearGradient.brand)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.textMuted)
        }
        .padding(AppDesign.paddingMd)
        .glassCard()
    }
}

#Preview {
    DashboardView()
        .environment(AuthService())
}
