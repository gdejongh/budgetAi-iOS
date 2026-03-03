//
//  ai_envelope_budgetApp.swift
//  ai envelope budget
//
//  Created by Gabe DeJongh on 3/3/26.
//

import SwiftUI

@main
struct ai_envelope_budgetApp: App {
    @State private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .preferredColorScheme(.dark)
        }
    }
}
