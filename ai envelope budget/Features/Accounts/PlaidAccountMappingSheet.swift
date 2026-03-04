//
//  PlaidAccountMappingSheet.swift
//  ai envelope budget
//
//  Created on 3/4/26.
//

import SwiftUI

struct PlaidAccountMappingSheet: View {
    @Environment(PlaidService.self) private var plaidService
    @Environment(AccountService.self) private var accountService
    @Environment(DataRefreshService.self) private var dataRefreshService
    @Environment(\.dismiss) private var dismiss

    let linkResult: PlaidLinkResult

    @State private var accountMappings: [AccountMapping] = []
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var selectedCount: Int {
        accountMappings.filter(\.isSelected).count
    }

    private var isValid: Bool {
        selectedCount > 0 && accountMappings.filter(\.isSelected).allSatisfy {
            !$0.displayName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppDesign.paddingLg) {
                    // Header
                    headerSection

                    // Account List
                    VStack(spacing: AppDesign.paddingSm) {
                        ForEach($accountMappings) { $mapping in
                            accountMappingRow(mapping: $mapping)
                        }
                    }
                    .padding(.horizontal, AppDesign.paddingMd)

                    // Info
                    infoSection

                    // Import Button
                    importButton
                }
                .padding(.bottom, AppDesign.paddingLg)
            }
            .navigationTitle("Link Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
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
        .onAppear {
            setupMappings()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppDesign.paddingSm) {
            Image(systemName: "building.columns.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentCyan)
                .padding(.top, AppDesign.paddingMd)

            if let name = linkResult.institutionName {
                Text(name)
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Text("\(linkResult.accounts.count) account\(linkResult.accounts.count == 1 ? "" : "s") found")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Account Mapping Row

    private func accountMappingRow(mapping: Binding<AccountMapping>) -> some View {
        VStack(spacing: AppDesign.paddingSm) {
            // Toggle + account info header
            HStack {
                Toggle(isOn: mapping.isSelected) {
                    HStack(spacing: 10) {
                        Image(systemName: mapping.wrappedValue.accountType.icon)
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mapping.wrappedValue.plaidAccount.name)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack(spacing: 4) {
                                if let masked = mapping.wrappedValue.plaidAccount.maskedNumber {
                                    Text(masked)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Text("·")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(mapping.wrappedValue.accountType.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(.accentCyan)
            }

            // Expanded settings when selected
            if mapping.wrappedValue.isSelected {
                VStack(spacing: AppDesign.paddingSm) {
                    // Custom name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account Name")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
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
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
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
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        Picker("Link to existing", selection: mapping.existingAccountId) {
                            Text("Create New Account").tag(String?.none)

                            ForEach(existingAccountsForType(mapping.wrappedValue.accountType), id: \.id) { account in
                                Text(account.name).tag(Optional(account.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .formFieldBackground()
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
                .font(.caption)

            Text("Selected accounts will be linked via Plaid for automatic balance and transaction syncing.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppDesign.paddingLg)
    }

    // MARK: - Import Button

    private var importButton: some View {
        Button {
            Task { await importAccounts() }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "link.circle.fill")
                }
                Text("Import \(selectedCount) Account\(selectedCount == 1 ? "" : "s")")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!isValid || isSubmitting)
        .padding(.horizontal, AppDesign.paddingLg)
    }

    // MARK: - Helpers

    private func existingAccountsForType(_ type: AccountType) -> [BankAccountResponse] {
        accountService.accounts.filter { account in
            account.resolvedType == type && !account.isPlaidLinked
        }
    }

    private func setupMappings() {
        accountMappings = linkResult.accounts.map { account in
            AccountMapping(
                plaidAccount: account,
                isSelected: true,
                displayName: account.name,
                accountType: account.suggestedAccountType,
                existingAccountId: nil
            )
        }
    }

    // MARK: - Import Action

    private func importAccounts() async {
        isSubmitting = true

        let selectedMappings = accountMappings.filter(\.isSelected)

        let accountLinks = selectedMappings.map { mapping in
            PlaidAccountLink(
                plaidAccountId: mapping.plaidAccount.id,
                existingBankAccountId: mapping.existingAccountId,
                accountName: mapping.displayName,
                accountType: mapping.accountType.rawValue,
                mask: mapping.plaidAccount.mask
            )
        }

        let request = ExchangeTokenRequest(
            publicToken: linkResult.publicToken,
            institutionId: linkResult.institutionId,
            institutionName: linkResult.institutionName,
            accountLinks: accountLinks
        )

        do {
            _ = try await plaidService.exchangeToken(request)
            await dataRefreshService.refreshAfterAccountChange()
            await plaidService.fetchPlaidItems()
            dismiss()
        } catch let error as APIError {
            errorMessage = error.errorDescription ?? "Failed to import accounts."
            showError = true
        } catch {
            errorMessage = "Failed to import accounts."
            showError = true
        }

        isSubmitting = false
    }
}

// MARK: - Account Mapping Model

struct AccountMapping: Identifiable {
    let id = UUID()
    let plaidAccount: PlaidLinkAccount
    var isSelected: Bool
    var displayName: String
    var accountType: AccountType
    var existingAccountId: String?
}
