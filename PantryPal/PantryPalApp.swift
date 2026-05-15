//
//  PantryPalApp.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import RevenueCat
import UIKit

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let shortcutItem = connectionOptions.shortcutItem else { return }
        Task { @MainActor in
            QuickActionService.shared.queue(actionType: shortcutItem.type)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor in
            QuickActionService.shared.queue(actionType: shortcutItem.type)
            completionHandler(true)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Configure App Check
        let providerFactory = RecipleaseAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        FirebaseApp.configure()
        
        #if DEBUG
        AppAnalytics.setAnalyticsCollectionEnabled(false)
        print("📊 Analytics disabled (debug mode)")
        #else
        AppAnalytics.log(.appLaunched, parameters: nil)
        print("📊 Analytics event logged: app_launched")
        #endif
        
        // Configure RevenueCat
        RevenueCatService.shared.configure()
        
        // Preload offerings in background for faster paywall display
        Task { @MainActor in
            // Wait a moment for RevenueCat to finish initializing
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            RevenueCatService.shared.preloadOfferings()
        }
        
        // Fetch tip of the day once on startup
        TipOfDayService.shared.loadTipOfDay()

        Self.configureMainNavigationBarAppearance()

        Task { @MainActor in
            MealPlanCalendarPromptCoordinator.armPlanTabPromptIfCalendarDisabled()
        }

        return true
    }

    /// Navigation titles use SF Pro to match in-app `Font.pantry*`.
    private static func configureMainNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        if let largeDesc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle).withDesign(.default) {
            let base = UIFont(descriptor: largeDesc, size: 34)
            let font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: base)
            appearance.largeTitleTextAttributes = [.font: font, .foregroundColor: UIColor.label]
        }
        if let titleDesc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline).withDesign(.default) {
            let base = UIFont(descriptor: titleDesc, size: 17)
            let font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: base)
            appearance.titleTextAttributes = [.font: font, .foregroundColor: UIColor.label]
        }

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

@main
struct PantryPalApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - App Check Provider Factory

class RecipleaseAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        return AppCheckDebugProvider(app: app)
        #else
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        } else {
            return DeviceCheckProvider(app: app)
        }
        #endif
    }
}
