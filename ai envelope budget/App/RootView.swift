//
//  RootView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var authService
    @State private var accountService = AccountService()
    @State private var envelopeService = EnvelopeService()
    @State private var transactionService = TransactionService()
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        Group {
            if authService.isAuthenticated {
                TabView(selection: $selectedTab) {
                    Tab("Dashboard", systemImage: "house.fill", value: .dashboard) {
                        NavigationStack {
                            DashboardView()
                        }
                    }

                    Tab("Envelopes", systemImage: "envelope.fill", value: .envelopes) {
                        NavigationStack {
                            EnvelopesView()
                        }
                    }

                    Tab("Transactions", systemImage: "arrow.left.arrow.right", value: .transactions) {
                        NavigationStack {
                            TransactionsView()
                        }
                    }

                    Tab("Accounts", systemImage: "building.columns.fill", value: .accounts) {
                        NavigationStack {
                            AccountsView()
                        }
                    }
                }
                .tint(.accentCyan)
                .toolbarBackground(Color.bgSurface, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .environment(accountService)
                .environment(envelopeService)
                .environment(transactionService)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                NavigationStack {
                    LoginView()
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: authService.isAuthenticated)
    }
}

// MARK: - App Tabs

enum AppTab: Hashable {
    case dashboard
    case envelopes
    case transactions
    case accounts
}

#Preview("Logged Out") {
    RootView()
        .environment(AuthService())
}
