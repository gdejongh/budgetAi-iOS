//
//  RootView.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                DashboardView()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                NavigationStack {
                    LoginView()
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: authService.isAuthenticated)
    }
}

#Preview("Logged Out") {
    RootView()
        .environment(AuthService())
}
