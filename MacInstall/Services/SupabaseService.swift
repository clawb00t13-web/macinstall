import Foundation

struct SupabaseService {
    /// Fetch profile YAML from Supabase. Returns empty string if no row exists.
    func fetchProfile(accessToken: String) async throws -> String {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/user_profiles?select=profile_yaml") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let (data, _) = try await URLSession.shared.data(for: request)
        let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        return rows?.first?["profile_yaml"] as? String ?? ""
    }

    /// Sync the list of installed app IDs detected on this Mac to Supabase.
    func upsertInstalledApps(accessToken: String, userId: String, appIds: [String]) async throws {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/user_profiles") else {
            throw URLError(.badURL)
        }
        let body: [String: Any] = [
            "user_id": userId,
            "installed_app_ids": appIds,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",          forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)",     forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: request)
    }

    /// Fetch the list of app IDs queued for uninstall from the web.
    func fetchUninstallQueue(accessToken: String) async throws -> [String] {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/user_profiles?select=uninstall_queue") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let (data, _) = try await URLSession.shared.data(for: request)
        let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        return rows?.first?["uninstall_queue"] as? [String] ?? []
    }

    /// Clear the uninstall queue in Supabase after processing.
    func clearUninstallQueue(accessToken: String, userId: String) async throws {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/user_profiles") else {
            throw URLError(.badURL)
        }
        let body: [String: Any] = [
            "user_id": userId,
            "uninstall_queue": [String](),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: request)
    }

    /// Upsert (insert or update) the user's profile YAML in Supabase.
    func upsertProfile(accessToken: String, userId: String, yaml: String) async throws {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/user_profiles") else {
            throw URLError(.badURL)
        }
        let body: [String: Any] = [
            "user_id": userId,
            "profile_yaml": yaml,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        _ = try await URLSession.shared.data(for: request)
    }
}
