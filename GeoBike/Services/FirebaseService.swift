import Foundation

// MARK: - Protocol
// This protocol abstracts all cloud persistence.
// To activate Firebase: add the Firebase Swift SDK via SPM
// (https://github.com/firebase/firebase-ios-sdk), uncomment FirebaseApp.configure()
// in GeoBikeApp.swift, and swap LocalUserService for FirebaseUserService below.

protocol UserServiceProtocol: AnyObject {
    func loadUser() async -> AppUser
    func saveUser(_ user: AppUser) async
    func logEvent(_ name: String, params: [String: Any])
}

// MARK: - Local Implementation (UserDefaults, works without Firebase)
final class LocalUserService: UserServiceProtocol {
    private let userKey = "geobike_user_v1"
    private let uid: String

    init() {
        if let saved = UserDefaults.standard.string(forKey: "geobike_uid") {
            uid = saved
        } else {
            let newUID = UUID().uuidString
            UserDefaults.standard.set(newUID, forKey: "geobike_uid")
            uid = newUID
        }
    }

    func loadUser() async -> AppUser {
        guard let data = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(AppUser.self, from: data) else {
            return AppUser(uid: uid)
        }
        return user
    }

    func saveUser(_ user: AppUser) async {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    func logEvent(_ name: String, params: [String: Any] = [:]) {
        // TODO: Replace with Analytics.logEvent(name, parameters: params)
        #if DEBUG
        print("[Analytics] \(name) \(params)")
        #endif
    }
}

// MARK: - Firebase Implementation (uncomment after adding Firebase SDK)

import FirebaseAuth
import FirebaseFirestore
import FirebaseAnalytics

final class FirebaseUserService: UserServiceProtocol {
    private let db = Firestore.firestore()
    private var uid: String {
        Auth.auth().currentUser?.uid ?? "anonymous"
    }

    func loadUser() async -> AppUser {
        do {
            if Auth.auth().currentUser == nil {
                try await Auth.auth().signInAnonymously()
            }
            let snapshot = try await db.collection("users").document(uid).getDocument()
            if let data = snapshot.data(), let user = try? Firestore.Decoder().decode(AppUser.self, from: data) {
                return user
            }
        } catch { print("Firebase load error:", error) }
        return AppUser(uid: uid)
    }

    func saveUser(_ user: AppUser) async {
        do {
            let data = try Firestore.Encoder().encode(user)
            try await db.collection("users").document(uid).setData(data, merge: true)
        } catch { print("Firebase save error:", error) }
    }

    func logEvent(_ name: String, params: [String: Any]) {
        Analytics.logEvent(name, parameters: params)
    }
}

