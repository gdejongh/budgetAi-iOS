//
//  AccountDetailView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct AccountDetailView: View {
    @Environment(AccountService.self) private var accountService
    @Environment(DataRefreshService.self) private var dataRefreshService
    @Environment(\.dismiss) private var dismiss

    let accountId: String

    @State private var showEditSheet = false
    @State private var showReconcileSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    /// Live account from the service (updates when edits happen)
    private var account: BankAccountResponse? {
        accountService.accounts.first { $0.id == accountId }
    }

    private var accountType: AccountType {
        account?.resolvedType ?? .checking
    }

    var body: some View {
        Group {
            if let account {
                List {
                    // Hero Section
                    Section {
                        heroContent(account)
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    }

                    // Account Info
                    Section("Account Details") {
                        if let masked = account.maskedNumber {
                            LabeledContent("Account Number", value: masked)
                        }

                        if let institution = account.institutionName {
                            LabeledContent("Institution", value: institution)
                        }

                        LabeledContent(
                            "Type",
                            value: account.manual == true ? "Manual" : "Plaid Linked"
                        )

                        if let createdAt = account.createdAt {
                            LabeledContent("Added", value: createdAt.asFormattedDate())
                        }

                        if let linkedAt = account.plaidLinkedAt, account.isPlaidLinked {
                            LabeledContent("Linked", value: linkedAt.asFormattedDate())
                        }
                    }

                    // Actions
                    Section("Actions") {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit Account", systemImage: "pencil")
                        }

                        if accountType.isCreditCard {
                            Button {
                                showReconcileSheet = true
                            } label: {
                                Label("Adjust Balance", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                    }

                    // Danger Zone
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Label("Delete Account", systemImage: "trash")
                                Spacer()
                                if isDeleting {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        .disabled(isDeleting)
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView(
                    "Account Not Found",
                    systemImage: "xmark.circle",
                    description: Text("This account may have been deleted.")
                )
            }
        }
        .navigationTitle(account?.name ?? "Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if account != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit Account", systemImage: "pencil")
                        }

                        if account?.resolvedType.isCreditCard == true {
                            Button {
                                showReconcileSheet = true
                            } label: {
                                Label("Adjust Balance", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Account", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let account {
                EditAccountSheet(account: account)
            }
        }
        .sheet(isPresented: $showReconcileSheet) {
            if let account {
                ReconcileBalanceSheet(account: account)
            }
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(account?.name ?? "this account")\"? This action cannot be undone.")
        }
    }

    // MARK: - Hero Content

    private func heroContent(_ account: BankAccountResponse) -> some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: accountType.icon)
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)

            // Balance
            VStack(spacing: 4) {
                Text(accountType.isCreditCard ? "Balance Owed" : "Available Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(account.currentBalance.asCurrency())
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(balanceColor(for: account))
            }

            // Type badge
            HStack(spacing: 8) {
                Text(accountType.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentViolet)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.accentViolet.opacity(0.15))
                    )

                if account.isPlaidLinked {
                    HStack(spacing: 3) {
                        Image(systemName: "link")
                            .font(.caption2)
                            .fontWeight(.bold)
                        Text("Linked")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.accentCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.accentCyan.opacity(0.15))
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func deleteAccount() async {
        guard let account else { return }
        isDeleting = true
        let success = await accountService.deleteAccount(account)
        if success {
            await dataRefreshService.refreshAfterAccountChange()
            dismiss()
        }
        isDeleting = false
    }

    // MARK: - Helpers

    private func balanceColor(for account: BankAccountResponse) -> Color {
        if account.resolvedType.isCreditCard {
            return account.currentBalance > 0 ? .warning : .success
        }
        return account.currentBalance >= 0 ? .success : .danger
    }
}
