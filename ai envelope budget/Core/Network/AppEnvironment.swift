//
//  AppEnvironment.swift
//  ai envelope budget
//
//  Created on 3/3/26.
//

import Foundation

nonisolated enum AppEnvironment {
    case development
    case production

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    var baseURL: String {
        switch self {
        case .development:
            return "http://localhost:8080"
        case .production:
            return "https://api.aienvelopebudget.com"
        }
    }

    var apiBaseURL: URL {
        URL(string: baseURL)!
    }
}
