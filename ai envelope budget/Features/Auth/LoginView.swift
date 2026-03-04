//
//  LoginView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var navigateToRegister = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password
    }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 60)

                // Logo & Title
                headerView

                // Form
                VStack(spacing: 20) {
                    if let error = authService.errorMessage {
                        ErrorBannerView(message: error)
                    }

                    emailField
                    passwordField
                    signInButton
                }
                .padding(.horizontal, AppDesign.paddingLg)

                registerLink

                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemBackground))
        .onDisappear { authService.clearError() }
        .navigationDestination(isPresented: $navigateToRegister) {
            RegisterView()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wallet.bifold.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            Text("BudgetAI")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.accentColor)

            Text("Envelope budgeting, powered by AI")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Email")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)

                TextField("you@example.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit { focusedField = .password }
            }
            .formFieldBackground()
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)

                Group {
                    if showPassword {
                        TextField("Enter your password", text: $password)
                    } else {
                        SecureField("Enter your password", text: $password)
                    }
                }
                .textContentType(.password)
                .submitLabel(.go)
                .focused($focusedField, equals: .password)
                .onSubmit { submitForm() }

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.tertiary)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
            }
            .formFieldBackground()
        }
    }

    private var signInButton: some View {
        Button {
            submitForm()
        } label: {
            Group {
                if authService.isLoading {
                    ProgressView()
                } else {
                    Text("Sign In")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!isFormValid || authService.isLoading)
    }

    private var registerLink: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .foregroundStyle(.secondary)

            Button("Sign Up") {
                authService.clearError()
                navigateToRegister = true
            }
            .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    // MARK: - Actions

    private func submitForm() {
        guard isFormValid, !authService.isLoading else { return }
        focusedField = nil
        Task {
            await authService.login(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
    .environment(AuthService())
}
