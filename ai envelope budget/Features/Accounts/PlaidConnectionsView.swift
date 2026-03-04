//
//  PlaidConnectionsView.swift
//  ai envelope budget
//
//  Created on 3/4/26.
//

import SwiftUI

/// Inline section showing linked Plaid connections with sync and unlink actions.
/// Designed to be embedded inside a List in AccountsView.
struct PlaidConnectionsSection: View {
    @Environment(PlaidService.self) private var plaidService
    @Environment(AccountService.self) private var accountService

    @State private var showSyncResult = false
    @State private var syncResultMessage = ""
    @State private var isSyncing = false
    @State private var showUnlinkConfirm = false
    @State private var itemToUnlink: PlaidItemResponse?

    var body: some View {
        if !plaidService.plaidItems.isEmpty {
            Section {
                ForEach(plaidService.plaidItems) { item in
                    plaidItemRow(item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                itemToUnlink = item
                                showUnlinkConfirm = true
                            } label: {
                                Label("Unlink", systemImage: "link.badge.plus")
                            }
                        }
                }

                // Sync button
                Button {
                    Task { await syncAllAccounts() }
                } label: {
                    HStack(spacing: 8) {
                        if isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text("Sync All Accounts")
                        Spacer()
                    }
                    .foregroundStyle(Color.accentCyan)
                }
                .disabled(isSyncing)
            } header: {
                HStack {
                    Text("Plaid Connections")
                    Spacer()
                    Text("\(plaidService.plaidItems.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .alert("Sync Complete", isPresented: $showSyncResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(syncResultMessage)
            }
            .confirmationDialog(
                "Unlink \(itemToUnlink?.institutionName ?? "this connection")?",
                isPresented: $showUnlinkConfirm,
                titleVisibility: .visible
            ) {
                Button("Unlink", role: .destructive) {
                    if let item = itemToUnlink {
                        Task { await unlinkItem(item) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    itemToUnlink = nil
                }
            } message: {
                Text("This will disconnect the bank and stop automatic syncing. Your existing accounts and transactions will be kept.")
            }
        }
    }

    // MARK: - Plaid Item Row

    private func plaidItemRow(_ item: PlaidItemResponse) -> some View {
        HStack(spacing: 12) {
            // Institution Icon
            Image(systemName: "building.columns.fill")
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
                    Text(item.institutionName ?? "Unknown Institution")
                        .font(.headline)
                        .lineLimit(1)

                    statusBadge(item.resolvedStatus)
                }

                HStack(spacing: 6) {
                    Text("\(item.accountCount) account\(item.accountCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let lastSynced = item.lastSyncedAt {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Synced \(lastSynced.asFormattedDate())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    // MARK: - Status Badge

    private func statusBadge(_ status: PlaidItemStatus) -> some View {
        let color: Color = switch status {
        case .active: .success
        case .error: .warning
        case .revoked: .danger
        case .unknown: .textMuted
        }

        return HStack(spacing: 2) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }

    // MARK: - Actions

    private func syncAllAccounts() async {
        isSyncing = true

        if let result = await plaidService.syncAll() {
            syncResultMessage = result.message
            showSyncResult = true
            await accountService.fetchAccounts()
            await plaidService.fetchPlaidItems()
        } else if let error = plaidService.errorMessage {
            syncResultMessage = error
            showSyncResult = true
        }

        isSyncing = false
    }

    private func unlinkItem(_ item: PlaidItemResponse) async {
        guard let id = item.id else { return }
        let success = await plaidService.unlinkItem(id)
        if success {
            await accountService.fetchAccounts()
        }
        itemToUnlink = nil
    }
}
