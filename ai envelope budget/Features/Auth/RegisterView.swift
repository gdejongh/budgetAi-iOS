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
        ZStack {
            backgroundView

            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)

                    headerView

                    VStack(spacing: 20) {
                        if let error = authService.errorMessage {
                            errorBanner(error)
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
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    authService.clearError()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    // MARK: - Subviews

    private var backgroundView: some View {
        Color.bgPrimary
            .ignoresSafeArea()
            .overlay(
                RadialGradient(
                    colors: [
                        Color.accentViolet.opacity(0.08),
                        Color.accentCyan.opacity(0.04),
                        Color.clear,
                    ],
                    center: .topTrailing,
                    startRadius: 80,
                    endRadius: 450
                )
                .ignoresSafeArea()
            )
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus.fill")
                .font(.system(size: 50))
                .foregroundStyle(LinearGradient.brand)
                .shadow(color: .accentViolet.opacity(0.4), radius: 16, x: 0, y: 4)

            GradientText("Create Account", font: .system(size: 28, weight: .bold))

            Text("Start your budgeting journey")
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
            .background(inputBackground)
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
                        TextField("", text: $password, prompt: Text("Min. 8 characters").foregroundStyle(Color.textMuted))
                    } else {
                        SecureField("", text: $password, prompt: Text("Min. 8 characters").foregroundStyle(Color.textMuted))
                    }
                }
                .textContentType(.newPassword)
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
            .background(inputBackground)

            if !password.isEmpty && password.count < 8 {
                Text("Password must be at least 8 characters")
                    .font(.caption2)
                    .foregroundStyle(Color.danger)
            }
        }
    }

    private var confirmPasswordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Confirm Password")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.textSecondary)

            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 20)

                Group {
                    if showConfirmPassword {
                        TextField("", text: $confirmPassword, prompt: Text("Re-enter your password").foregroundStyle(Color.textMuted))
                    } else {
                        SecureField("", text: $confirmPassword, prompt: Text("Re-enter your password").foregroundStyle(Color.textMuted))
                    }
                }
                .textContentType(.newPassword)
                .foregroundStyle(Color.textPrimary)

                Button {
                    showConfirmPassword.toggle()
                } label: {
                    Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
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
                            .stroke(!passwordsMatch ? Color.danger.opacity(0.5) : Color.borderSubtle, lineWidth: 1)
                    )
            )

            if !passwordsMatch {
                Text("Passwords do not match")
                    .font(.caption2)
                    .foregroundStyle(Color.danger)
            }
        }
    }

    private var createAccountButton: some View {
        Button {
            Task {
                await authService.register(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            }
        } label: {
            Group {
                if authService.isLoading {
                    ProgressView()
                        .tint(.bgPrimary)
                } else {
                    Text("Create Account")
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
        .glowShadow(color: isFormValid ? .accentViolet : .clear, radius: isFormValid ? 8 : 0)
        .animation(.easeInOut(duration: 0.2), value: isFormValid)
    }

    private var signInLink: some View {
        HStack(spacing: 4) {
            Text("Already have an account?")
                .foregroundStyle(Color.textSecondary)

            Button("Sign In") {
                authService.clearError()
                dismiss()
            }
            .foregroundStyle(Color.accentCyan)
            .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    // MARK: - Helpers

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
            .fill(Color.bgInput)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.cornerRadiusMd)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
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
        RegisterView()
    }
    .environment(AuthService())
}
