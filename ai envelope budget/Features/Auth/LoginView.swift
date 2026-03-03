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

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack {
            // Background gradient
            backgroundView

            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)

                    // Logo & Title
                    headerView

                    // Form
                    VStack(spacing: 20) {
                        // Error banner
                        if let error = authService.errorMessage {
                            errorBanner(error)
                        }

                        emailField
                        passwordField
                        signInButton
                    }
                    .padding(.horizontal, AppDesign.paddingLg)

                    // Register link
                    registerLink

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationDestination(isPresented: $navigateToRegister) {
            RegisterView()
        }
    }

    // MARK: - Subviews

    private var backgroundView: some View {
        Color.bgPrimary
            .ignoresSafeArea()
            .overlay(
                RadialGradient(
                    colors: [
                        Color.accentCyan.opacity(0.08),
                        Color.accentViolet.opacity(0.04),
                        Color.clear,
                    ],
                    center: .top,
                    startRadius: 100,
                    endRadius: 500
                )
                .ignoresSafeArea()
            )
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wallet.bifold.fill")
                .font(.system(size: 56))
                .foregroundStyle(LinearGradient.brand)
                .shadow(color: .accentCyan.opacity(0.4), radius: 16, x: 0, y: 4)

            GradientText("BudgetAI", font: .system(size: 34, weight: .bold))

            Text("Envelope budgeting, powered by AI")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Email")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.textSecondary)

            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 20)

                TextField("", text: $email, prompt: Text("you@example.com").foregroundStyle(Color.textMuted))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                    .fill(Color.bgInput)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                            .stroke(Color.borderSubtle, lineWidth: 1)
                    )
            )
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.textSecondary)

            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 20)

                Group {
                    if showPassword {
                        TextField("", text: $password, prompt: Text("Enter your password").foregroundStyle(Color.textMuted))
                    } else {
                        SecureField("", text: $password, prompt: Text("Enter your password").foregroundStyle(Color.textMuted))
                    }
                }
                .textContentType(.password)
                .foregroundStyle(Color.textPrimary)

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(Color.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                    .fill(Color.bgInput)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                            .stroke(Color.borderSubtle, lineWidth: 1)
                    )
            )
        }
    }

    private var signInButton: some View {
        Button {
            Task {
                await authService.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
            }
        } label: {
            Group {
                if authService.isLoading {
                    ProgressView()
                        .tint(.bgPrimary)
                } else {
                    Text("Sign In")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                .fill(isFormValid ? LinearGradient.brand : LinearGradient(colors: [Color.textMuted.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
        )
        .foregroundStyle(isFormValid ? Color.bgPrimary : Color.textMuted)
        .disabled(!isFormValid || authService.isLoading)
        .glowShadow(color: isFormValid ? .accentCyan : .clear, radius: isFormValid ? 8 : 0)
        .animation(.easeInOut(duration: 0.2), value: isFormValid)
    }

    private var registerLink: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .foregroundStyle(Color.textSecondary)

            Button("Sign Up") {
                authService.clearError()
                navigateToRegister = true
            }
            .foregroundStyle(Color.accentCyan)
            .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.danger)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.danger)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                .fill(Color.danger.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                        .stroke(Color.danger.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: authService.errorMessage)
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
    .environment(AuthService())
}
