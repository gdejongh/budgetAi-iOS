//
//  AppleWalletConnectionSheet.swift
//  ai envelope budget
//
//  Created on 3/5/26.
//

import SwiftUI

/// Sheet for discovering and linking Apple Wallet accounts (Apple Card,
/// Apple Cash, Apple Savings) via FinanceKit.
/// Mirrors the design pattern of PlaidAccountMappingSheet.
struct AppleWalletConnectionSheet: View {
    @Environment(AppleWalletService.self) private var walletService
    @Environment(AccountService.self) private var accountService
    @Environment(DataRefreshService.self) private var dataRefreshService
    @Environment(\.dismiss) private var dismiss

    @State private var mappings: [WalletAccountMapping] = []
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isDiscovering = true

    private var selectedCount: Int {
        mappings.filter(\.isSelected).count
    }

    private var linkableCount: Int {
        mappings.filter { $0.isSelected && $0.account.isLinkable }.count
    }

    private var isValid: Bool {
        linkableCount > 0 && mappings.filter(\.isSelected).allSatisfy {
            !$0.displayName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isDiscovering {
                    discoveryLoadingView
                } else if walletService.authStatus == .denied {
                    accessDeniedView
                } else if walletService.discoveredAccounts.isEmpty {
                    noAccountsView
                } else {
                    accountSelectionView
                }
            }
            .navigationTitle("Apple Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            await discoverAccounts()
        }
    }

    // MARK: - Discovery Loading

    private var discoveryLoadingView: some View {
        VStack(spacing: AppDesign.paddingLg) {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .tint(.accentCyan)

            VStack(spacing: AppDesign.paddingSm) {
                Text("Discovering Accounts")
                    .font(.appTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)

                Text("Looking for Apple Wallet accounts on this device…")
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(AppDesign.paddingLg)
    }

    // MARK: - Access Denied

    private var accessDeniedView: some View {
        ContentUnavailableView {
            Label("Access Denied", systemImage: "lock.shield.fill")
                .foregroundStyle(Color.warning)
        } description: {
            Text("Budget AI needs permission to read your Apple Wallet data. Go to Settings → Privacy & Security → Finance to allow access.")
                .foregroundStyle(Color.textSecondary)
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: - No Accounts

    private var noAccountsView: some View {
        ContentUnavailableView {
            Label("No Accounts Found", systemImage: "wallet.bifold.fill")
                .foregroundStyle(Color.accentCyan)
        } description: {
            Text("No Apple Wallet financial accounts were found on this device. Make sure you have Apple Card, Apple Cash, or Apple Savings set up in Wallet.")
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Account Selection

    private var accountSelectionView: some View {
        ScrollView {
            VStack(spacing: AppDesign.paddingLg) {
                // Header
                headerSection

                // Account List
                VStack(spacing: AppDesign.paddingSm) {
                    ForEach($mappings) { $mapping in
                        walletAccountRow(mapping: $mapping)
                    }
                }
                .padding(.horizontal, AppDesign.paddingMd)

                // Info
                infoSection

                // Link Button
                linkButton
            }
            .padding(.bottom, AppDesign.paddingLg)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppDesign.paddingSm) {
            Image(systemName: "wallet.bifold.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentCyan)
                .padding(.top, AppDesign.paddingMd)

            Text("Apple Wallet")
                .font(.appTitle)
                .fontWeight(.bold)

            Text("\(walletService.discoveredAccounts.count) account\(walletService.discoveredAccounts.count == 1 ? "" : "s") found")
                .font(.appBody)
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Account Row

    private func walletAccountRow(mapping: Binding<WalletAccountMapping>) -> some View {
        let account = mapping.wrappedValue.account

        return VStack(spacing: AppDesign.paddingSm) {
            HStack {
                Toggle(isOn: mapping.isSelected) {
                    HStack(spacing: 10) {
                        Image(systemName: account.accountType.icon)
                            .font(.appTitle)
                            .foregroundStyle(account.isLinkable ? Color.accentCyan : Color.textMuted)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                                .font(.appBody)
                                .fontWeight(.medium)
                                .foregroundStyle(
                                    account.isLinkable ? Color.textPrimary : Color.textMuted
                                )

                            HStack(spacing: 4) {
                                Text(account.institutionName)
                                    .font(.appCaption)
                                    .foregroundStyle(Color.textSecondary)

                                Text("·")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.textMuted)

                                Text(account.accountType.displayName)
                                    .font(.appCaption)
                                    .foregroundStyle(Color.textSecondary)
                            }

                            if account.isAlreadyLinkedViaPlaid {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                    Text("Already linked via Plaid")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(Color.warning)
                                .padding(.top, 2)
                            }

                            if account.isAlreadyLinkedViaWallet {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                    Text("Already connected")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(Color.success)
                                .padding(.top, 2)
                            }
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(.accentCyan)
                .disabled(!account.isLinkable)
            }

            // Expanded settings when selected and linkable
            if mapping.wrappedValue.isSelected && account.isLinkable {
                VStack(spacing: AppDesign.paddingSm) {
                    // Custom name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account Name")
                            .font(.appCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        TextField("Account name", text: mapping.displayName)
                            .textFieldStyle(.plain)
                            .formFieldBackground()
                            .autocorrectionDisabled()
                    }

                    // Account type picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account Type")
                            .font(.appCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        Picker("Type", selection: mapping.accountType) {
                            ForEach(AccountType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Link to existing account (optional)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Link To")
                            .font(.appCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        Picker("Link to existing", selection: mapping.existingAccountId) {
                            Text("Create New Account").tag(String?.none)

                            ForEach(
                                existingAccountsForType(mapping.wrappedValue.accountType),
                                id: \.id
                            ) { account in
                                Text(account.name).tag(Optional(account.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .formFieldBackground()
                    }

                    // Balance preview
                    HStack {
                        Text("Current Balance")
                            .font(.appCaption)
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Text(account.currentBalance.asCurrency())
                            .font(.appBody)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textPrimary)
                    }
                }
                .padding(.leading, 42)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(AppDesign.paddingMd)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .animation(.spring(duration: 0.3), value: mapping.wrappedValue.isSelected)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.accentCyan)
                .font(.appCaption)

            Text("Selected accounts will be synced automatically from Apple Wallet. Transactions and balances update each time you open the app.")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, AppDesign.paddingLg)
    }

    // MARK: - Link Button

    private var linkButton: some View {
        Button {
            Task { await linkSelectedAccounts() }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "wallet.bifold.fill")
                }
                Text("Connect \(linkableCount) Account\(linkableCount == 1 ? "" : "s")")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .controlSize(.large)
        .disabled(!isValid || isSubmitting)
        .padding(.horizontal, AppDesign.paddingLg)
    }

    // MARK: - Actions

    private func discoverAccounts() async {
        isDiscovering = true
        let authorized = await walletService.requestAuthorization()
        if authorized {
            await walletService.discoverAccounts(existingAccounts: accountService.accounts)
            setupMappings()
        }
        isDiscovering = false
    }

    private func linkSelectedAccounts() async {
        isSubmitting = true

        let selectedMappings = mappings.filter { $0.isSelected && $0.account.isLinkable }

        for mapping in selectedMappings {
            let success = await walletService.linkAccount(
                mapping.account,
                customName: mapping.displayName,
                existingAccountId: mapping.existingAccountId
            )

            if !success {
                errorMessage = walletService.errorMessage ?? "Failed to link \(mapping.account.name)."
                showError = true
                isSubmitting = false
                return
            }
        }

        // Refresh all data
        await dataRefreshService.refreshAfterAccountChange()

        isSubmitting = false
        dismiss()
    }

    // MARK: - Helpers

    private func setupMappings() {
        mappings = walletService.discoveredAccounts.map { account in
            WalletAccountMapping(
                account: account,
                isSelected: account.isLinkable,
                displayName: account.name,
                accountType: account.accountType,
                existingAccountId: nil
            )
        }
    }

    private func existingAccountsForType(_ type: AccountType) -> [BankAccountResponse] {
        accountService.accounts.filter { account in
            account.resolvedType == type && (account.manual == true)
        }
    }
}

// MARK: - Wallet Account Mapping Model

struct WalletAccountMapping: Identifiable {
    let id = UUID()
    let account: DiscoveredAppleWalletAccount
    var isSelected: Bool
    var displayName: String
    var accountType: AccountType
    var existingAccountId: String?
}
