//
//  RegisterView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct RegisterView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password, confirmPassword
    }

    private var isFormValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        return !trimmedEmail.isEmpty
            && password.count >= 8
            && password == confirmPassword
    }

    private var passwordsMatch: Bool {
        confirmPassword.isEmpty || password == confirmPassword
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)

                headerView

                VStack(spacing: 20) {
                    if let error = authService.errorMessage {
                        ErrorBannerView(message: error)
                    }

                    emailField
                    passwordField
                    confirmPasswordField
                    createAccountButton
                }
                .padding(.horizontal, AppDesign.paddingLg)

                signInLink

                Spacer(minLength: 40)
            }
        }
        .onDisappear { authService.clearError() }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus.fill")
                .font(.system(size: 50))
                .gradientForeground()

            Text("Create Account")
                .font(.appTitle)
                .headingTracking()
                .gradientForeground()

            Text("Start your budgeting journey")
                .font(.appSubheadline)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Email")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)

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
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)

            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)

                Group {
                    if showPassword {
                        TextField("Min. 8 characters", text: $password)
                    } else {
                        SecureField("Min. 8 characters", text: $password)
                    }
                }
                .textContentType(.newPassword)
                .submitLabel(.next)
                .focused($focusedField, equals: .password)
                .onSubmit { focusedField = .confirmPassword }

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

            if !password.isEmpty && password.count < 8 {
                Text("Password must be at least 8 characters")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private var confirmPasswordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Confirm Password")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)

            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)

                Group {
                    if showConfirmPassword {
                        TextField("Re-enter your password", text: $confirmPassword)
                    } else {
                        SecureField("Re-enter your password", text: $confirmPassword)
                    }
                }
                .textContentType(.newPassword)
                .submitLabel(.go)
                .focused($focusedField, equals: .confirmPassword)
                .onSubmit { submitForm() }

                Button {
                    showConfirmPassword.toggle()
                } label: {
                    Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.tertiary)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(showConfirmPassword ? "Hide password" : "Show password")
            }
            .formFieldBackground()

            if !passwordsMatch {
                Text("Passwords do not match")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private var createAccountButton: some View {
        Button {
            submitForm()
        } label: {
            Group {
                if authService.isLoading {
                    ProgressView()
                } else {
                    Text("Create Account")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .controlSize(.large)
        .disabled(!isFormValid || authService.isLoading)
    }

    private var signInLink: some View {
        HStack(spacing: 4) {
            Text("Already have an account?")
                .foregroundStyle(Color.textSecondary)

            Button("Sign In") {
                authService.clearError()
                dismiss()
            }
            .fontWeight(.semibold)
        }
        .font(.appSubheadline)
    }

    // MARK: - Actions

    private func submitForm() {
        guard isFormValid, !authService.isLoading else { return }
        focusedField = nil
        Task {
            await authService.register(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
    }
    .environment(AuthService())
}
