//
//  AccountDetailView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct AccountDetailView: View {
    @Environment(AccountService.self) private var accountService
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
        ZStack {
            Color.bgPrimary
                .ignoresSafeArea()

            if let account {
                ScrollView {
                    VStack(spacing: AppDesign.paddingLg) {
                        // Hero Card
                        heroCard(account)

                        // Account Info
                        infoSection(account)

                        // Actions
                        actionsSection(account)

                        // Danger Zone
                        dangerSection
                    }
                    .padding(.horizontal, AppDesign.paddingLg)
                    .padding(.vertical, AppDesign.paddingMd)
                }
            } else {
                // Account was deleted or not found
                VStack(spacing: 16) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.textMuted)
                    Text("Account not found")
                        .font(.headline)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .navigationTitle(account?.name ?? "Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
                            .foregroundStyle(LinearGradient.brand)
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

    // MARK: - Hero Card

    private func heroCard(_ account: BankAccountResponse) -> some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: accountType.icon)
                .font(.system(size: 44))
                .foregroundStyle(LinearGradient.brand)
                .shadow(color: .accentCyan.opacity(0.3), radius: 16)

            // Balance
            VStack(spacing: 4) {
                Text(accountType.isCreditCard ? "Balance Owed" : "Available Balance")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)

                Text(formatCurrency(account.currentBalance))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(balanceColor(for: account))
            }

            // Type badge
            HStack(spacing: 8) {
                Text(accountType.displayName)
                    .font(.system(size: 12, weight: .semibold))
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
                            .font(.system(size: 9, weight: .bold))
                        Text("Linked")
                            .font(.system(size: 12, weight: .semibold))
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
        .frame(maxWidth: .infinity)
        .padding(AppDesign.paddingLg)
        .glassCard()
    }

    // MARK: - Info Section

    private func infoSection(_ account: BankAccountResponse) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.paddingSm) {
            sectionHeader("Account Details", icon: "info.circle.fill")

            VStack(spacing: 0) {
                if let masked = account.maskedNumber {
                    infoRow(label: "Account Number", value: masked)
                    Divider().overlay(Color.borderSubtle)
                }

                if let institution = account.institutionName {
                    infoRow(label: "Institution", value: institution)
                    Divider().overlay(Color.borderSubtle)
                }

                infoRow(
                    label: "Type",
                    value: account.manual == true ? "Manual" : "Plaid Linked"
                )

                if let createdAt = account.createdAt {
                    Divider().overlay(Color.borderSubtle)
                    infoRow(label: "Added", value: formatDate(createdAt))
                }

                if let linkedAt = account.plaidLinkedAt, account.isPlaidLinked {
                    Divider().overlay(Color.borderSubtle)
                    infoRow(label: "Linked", value: formatDate(linkedAt))
                }
            }
            .glassCard()
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, AppDesign.paddingMd)
        .padding(.vertical, 12)
    }

    // MARK: - Actions Section

    private func actionsSection(_ account: BankAccountResponse) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.paddingSm) {
            sectionHeader("Actions", icon: "bolt.fill")

            VStack(spacing: AppDesign.paddingSm) {
                actionButton(
                    icon: "pencil",
                    title: "Edit Account",
                    subtitle: "Change name\(account.manual == true ? " or balance" : "")",
                    color: .accentCyan
                ) {
                    showEditSheet = true
                }

                if accountType.isCreditCard {
                    actionButton(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Adjust Balance",
                        subtitle: "Reconcile to actual statement balance",
                        color: .accentViolet
                    ) {
                        showReconcileSheet = true
                    }
                }
            }
        }
    }

    private func actionButton(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                            .fill(color.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
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
        .buttonStyle(.plain)
    }

    // MARK: - Danger Section

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.paddingSm) {
            sectionHeader("Danger Zone", icon: "exclamationmark.triangle.fill")

            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "trash.fill")
                        .font(.title3)
                        .foregroundStyle(Color.danger)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusSm)
                                .fill(Color.danger.opacity(0.1))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete Account")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.danger)

                        Text("Permanently remove this account and all data")
                            .font(.caption)
                            .foregroundStyle(Color.textMuted)
                    }

                    Spacer()

                    if isDeleting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.danger)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.textMuted)
                    }
                }
                .padding(AppDesign.paddingMd)
                .background(
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusLg)
                        .fill(Color.bgCard.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusLg)
                                .stroke(Color.danger.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(LinearGradient.brand)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Actions

    private func deleteAccount() async {
        guard let account else { return }
        isDeleting = true
        let success = await accountService.deleteAccount(account)
        if success {
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

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    private func formatDate(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none

        if let date = isoFormatter.date(from: isoString) {
            return displayFormatter.string(from: date)
        }
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: isoString) {
            return displayFormatter.string(from: date)
        }
        return isoString
    }
}
