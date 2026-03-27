import Foundation
import AuthenticationServices
import Security
import CryptoKit

struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let fullName: String?
    let avatarURL: String?
}

@MainActor
class AuthService: NSObject, ObservableObject {
    @Published var session: SupabaseSession?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let keychainService = "com.macinstall.supabase"
    private let keychainAccount = "session"
    // Retained to prevent deallocation before callback fires
    private var webAuthSession: ASWebAuthenticationSession?

    // MARK: - Google Sign In (Supabase OAuth + PKCE)

    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil

        let verifier = makeCodeVerifier()
        let challenge = makeCodeChallenge(from: verifier)

        var components = URLComponents(string: "\(SupabaseConfig.supabaseURL)/auth/v1/authorize")!
        components.queryItems = [
            URLQueryItem(name: "provider",              value: "google"),
            URLQueryItem(name: "redirect_to",           value: "macinstall://auth"),
            URLQueryItem(name: "code_challenge",        value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
        ]

        guard let authURL = components.url else {
            isLoading = false
            errorMessage = "Invalid Supabase URL — check SupabaseConfig.swift"
            return
        }

        let authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "macinstall"
        ) { [weak self] callbackURL, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.webAuthSession = nil

                if let error = error as? ASWebAuthenticationSessionError {
                    if error.code != .canceledLogin {
                        self.errorMessage = error.localizedDescription
                    }
                    self.isLoading = false
                    return
                }
                if let error {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    self.isLoading = false
                    self.errorMessage = "No auth code received — check Supabase redirect URL config"
                    return
                }
                await self.exchangePKCECode(code, verifier: verifier)
            }
        }
        authSession.presentationContextProvider = self
        authSession.prefersEphemeralWebBrowserSession = false
        webAuthSession = authSession
        authSession.start()
    }

    func signOut() {
        session = nil
        deleteFromKeychain()
    }

    func restoreSession() {
        session = loadFromKeychain()
    }

    // MARK: - PKCE Helpers

    private func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makeCodeChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func exchangePKCECode(_ code: String, verifier: String) async {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/auth/v1/token?grant_type=pkce") else {
            isLoading = false
            errorMessage = "Invalid Supabase URL"
            return
        }

        let body = ["auth_code": code, "code_verifier": verifier]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            isLoading = false
            errorMessage = "Failed to encode token request"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",          forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = bodyData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json       = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let access     = json["access_token"]  as? String,
                  let refresh    = json["refresh_token"] as? String,
                  let user       = json["user"]          as? [String: Any],
                  let userId     = user["id"]            as? String
            else {
                isLoading = false
                errorMessage = "Unexpected response from Supabase — check project config"
                return
            }
            let metadata  = user["user_metadata"] as? [String: Any]
            let fullName  = metadata?["full_name"]  as? String
            let avatarURL = metadata?["avatar_url"] as? String
            let newSession = SupabaseSession(accessToken: access, refreshToken: refresh, userId: userId, fullName: fullName, avatarURL: avatarURL)
            saveToKeychain(newSession)
            session = newSession
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Apple Sign In (future — requires Apple Developer account + capability)

    func signInWithApple() {
        // Not wired to the UI yet. Implementation:
        // 1. Enable "Sign In with Apple" in Xcode target capabilities
        // 2. Call the Apple ID provider and exchange the identity token
        //    with Supabase at /auth/v1/token?grant_type=id_token
    }

    // MARK: - Keychain

    private func saveToKeychain(_ session: SupabaseSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func loadFromKeychain() -> SupabaseSession? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    // Called on the main thread by the framework — MainActor.assumeIsolated is safe here.
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApplication.shared.windows.first(where: { $0.isVisible }) ?? NSWindow()
        }
    }
}
