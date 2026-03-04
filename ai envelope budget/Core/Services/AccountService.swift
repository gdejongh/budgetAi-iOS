//
//  AccountService.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class AccountService {
    // MARK: - State

    var accounts: [BankAccountResponse] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Computed Properties

    /// Bank accounts (checking + savings)
    var bankAccounts: [BankAccountResponse] {
        accounts.filter { !$0.resolvedType.isCreditCard }
    }

    /// Credit card accounts
    var creditCards: [BankAccountResponse] {
        accounts.filter { $0.resolvedType.isCreditCard }
    }

    /// Sum of all bank account balances
    var totalBankBalance: Decimal {
        bankAccounts.reduce(Decimal.zero) { $0 + $1.currentBalance }
    }

    /// Sum of all credit card balances (debt)
    var totalCreditCardDebt: Decimal {
        creditCards.reduce(Decimal.zero) { $0 + $1.currentBalance }
    }

    /// Net worth = bank balances - credit card debt
    var netWorth: Decimal {
        totalBankBalance - totalCreditCardDebt
    }

    // MARK: - Dependencies

    private let api: APIClient

    // MARK: - Init

    init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: - Fetch Accounts

    func fetchAccounts() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [BankAccountResponse] = try await api.request(
                .get,
                path: "/api/bank-accounts",
                authenticated: true
            )
            accounts = response
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to load accounts."
        }

        isLoading = false
    }

    // MARK: - Create Account

    func createAccount(name: String, type: AccountType, balance: Decimal) async -> Bool {
        errorMessage = nil

        let request = CreateBankAccountRequest(
            name: name,
            accountType: type,
            currentBalance: balance
        )

        do {
            let newAccount: BankAccountResponse = try await api.request(
                .post,
                path: "/api/bank-accounts",
                body: request,
                authenticated: true
            )
            accounts.append(newAccount)
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to create account."
            return false
        }
    }

    // MARK: - Update Account

    func updateAccount(_ account: BankAccountResponse, name: String, balance: Decimal) async -> Bool {
        guard let id = account.id, let appUserId = account.appUserId else { return false }
        errorMessage = nil

        let request = UpdateBankAccountRequest(
            id: id,
            appUserId: appUserId,
            name: name,
            accountType: account.resolvedType,
            currentBalance: balance
        )

        do {
            let updated: BankAccountResponse = try await api.request(
                .put,
                path: "/api/bank-accounts/\(id)",
                body: request,
                authenticated: true
            )
            if let index = accounts.firstIndex(where: { $0.id == id }) {
                accounts[index] = updated
            }
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to update account."
            return false
        }
    }

    // MARK: - Reconcile Balance

    func reconcileAccount(_ account: BankAccountResponse, targetBalance: Decimal) async -> Bool {
        guard let id = account.id else { return false }
        errorMessage = nil

        let request = ReconcileBalanceRequest(targetBalance: targetBalance)

        do {
            let updated: BankAccountResponse = try await api.request(
                .post,
                path: "/api/bank-accounts/\(id)/reconcile",
                body: request,
                authenticated: true
            )
            if let index = accounts.firstIndex(where: { $0.id == id }) {
                accounts[index] = updated
            }
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to reconcile balance."
            return false
        }
    }

    // MARK: - Delete Account

    func deleteAccount(_ account: BankAccountResponse) async -> Bool {
        guard let id = account.id else { return false }
        errorMessage = nil

        do {
            try await api.requestVoid(
                .delete,
                path: "/api/bank-accounts/\(id)",
                authenticated: true
            )
            accounts.removeAll { $0.id == id }
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "Failed to delete account."
            return false
        }
    }
}
