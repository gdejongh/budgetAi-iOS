//
//  AppleWalletConnectionsSection.swift
//  ai envelope budget
//
//  Created on 3/5/26.
//

import SwiftUI

/// Inline section showing linked Apple Wallet connections with sync status
/// and unlink actions. Embedded inside the List in AccountsView, alongside
/// PlaidConnectionsSection.
struct AppleWalletConnectionsSection: View {
    @Environment(AppleWalletService.self) private var walletService
    @Environment(AccountService.self) private var accountService
    @Environment(DataRefreshService.self) private var dataRefreshService

    @State private var showUnlinkConfirm = false
    @State private var linkToUnlink: AppleWalletAccountLink?

    var body: some View {
        if !walletService.linkedAccounts.isEmpty {
            Section {
                ForEach(walletService.linkedAccounts) { link in
                    walletLinkRow(link)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                linkToUnlink = link
                                showUnlinkConfirm = true
                            } label: {
                                Label("Disconnect", systemImage: "minus.circle")
                            }
                        }
                }

                // Sync status
                syncStatusRow
            } header: {
                HStack {
                    Text("Apple Wallet")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text("\(walletService.linkedAccounts.count)")
                        .font(.appCaption)
                        .foregroundStyle(Color.textMuted)
                }
            }
            .confirmationDialog(
                "Disconnect \(linkToUnlink?.accountName ?? "this account")?",
                isPresented: $showUnlinkConfirm,
                titleVisibility: .visible
            ) {
                Button("Disconnect", role: .destructive) {
                    if let link = linkToUnlink {
                        walletService.unlinkAccount(link)
                    }
                }
                Button("Cancel", role: .cancel) {
                    linkToUnlink = nil
                }
            } message: {
                Text("This will stop syncing from Apple Wallet. Your existing account and transactions will be kept.")
            }
        }
    }

    // MARK: - Wallet Link Row

    private func walletLinkRow(_ link: AppleWalletAccountLink) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "wallet.bifold.fill")
                .font(.title3)
                .foregroundStyle(Color.accentCyan)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                        .fill(Color.accentCyan.opacity(0.1))
                )

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(link.accountName)
                        .font(.appBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    BadgeView(text: "Connected", color: .success, icon: "checkmark")
                }

                HStack(spacing: 6) {
                    Text(link.accountType.displayName)
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)

                    if let lastSynced = link.lastSyncedAt {
                        Text("·")
                            .font(.appCaption)
                            .foregroundStyle(Color.textMuted)

                        Text("Synced \(lastSynced.formatted(.relative(presentation: .named)))")
                            .font(.appCaption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    // MARK: - Sync Status Row

    private var syncStatusRow: some View {
        Group {
            switch walletService.syncState {
            case .idle:
                EmptyView()

            case .syncing:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Syncing Apple Wallet…")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                }

            case .success(let count):
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.success)
                    Text(count > 0
                        ? "\(count) new transaction\(count == 1 ? "" : "s") synced"
                        : "All up to date")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                }

            case .error(let message):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.warning)
                    Text(message)
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                }
            }
        }
    }
}
