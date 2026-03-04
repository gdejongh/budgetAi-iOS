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
            #if targetEnvironment(simulator)
            return "http://localhost:8080"
            #else
            return "http://10.0.0.233:8080"
            #endif
        case .production:
            return "https://api.aienvelopebudget.com"
        }
    }

    var apiBaseURL: URL {
        URL(string: baseURL)!
    }
}
