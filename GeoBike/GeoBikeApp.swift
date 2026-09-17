import SwiftUI
import UserNotifications

// To activate Firebase:
// 1. Add Firebase iOS SDK via File > Add Package Dependencies
//    URL: https://github.com/firebase/firebase-ios-sdk
//    Products: FirebaseFirestore, FirebaseAuth, FirebaseAnalytics
// 2. Add your GoogleService-Info.plist to the project
// 3. Uncomment the FirebaseApp.configure() line below
// 4. In FirebaseService.swift, swap LocalUserService for FirebaseUserService

import FirebaseCore

@main
struct GeoBikeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()  // ← Uncomment after adding Firebase
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                  willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
}
