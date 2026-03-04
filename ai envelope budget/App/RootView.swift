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
    @State private var plaidService = PlaidService()
    @State private var aiAdviceService = AiAdviceService()
    @State private var dataRefreshService: DataRefreshService?
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        Group {
            if authService.isAuthenticated {
                TabView(selection: $selectedTab) {
                    Tab("Dashboard", systemImage: "house.fill", value: .dashboard) {
                        NavigationStack {
                            DashboardView(selectedTab: $selectedTab)
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
                .environment(accountService)
                .environment(envelopeService)
                .environment(transactionService)
                .environment(plaidService)
                .environment(aiAdviceService)
                .environment(resolvedRefreshService)
                .transition(.opacity)
            } else {
                NavigationStack {
                    LoginView()
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: authService.isAuthenticated)
    }

    /// Lazily create the refresh service so the @State services are initialized first.
    private var resolvedRefreshService: DataRefreshService {
        if let existing = dataRefreshService { return existing }
        let service = DataRefreshService(
            accountService: accountService,
            envelopeService: envelopeService,
            transactionService: transactionService
        )
        // Dispatch to avoid mutating state during view update
        DispatchQueue.main.async { dataRefreshService = service }
        return service
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
