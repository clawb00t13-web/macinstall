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

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let yaml = rows?.first?["profile_yaml"] as? String ?? ""
        print("[Supabase] fetchProfile → \(status) | \(yaml.isEmpty ? "(empty)" : "\(yaml.count) chars")")
        return yaml
    }

    /// Sync the list of installed app IDs detected on this Mac to Supabase.
    func upsertInstalledApps(accessToken: String, userId: String, appIds: [String]) async throws {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/user_profiles?on_conflict=user_id") else {
            throw URLError(.badURL)
        }
        let body: [String: Any] = [
            "user_id": userId,
            "installed_app_ids": appIds,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",             forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)",        forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("resolution=merge-duplicates",  forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status >= 300 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[Supabase] upsertInstalledApps → \(status) ERROR: \(body)")
        } else {
            print("[Supabase] upsertInstalledApps → \(status) | \(appIds.count) apps: \(appIds.joined(separator: ", "))")
        }
    }

    /// Fetch the list of app IDs queued for uninstall from the web.
    func fetchUninstallQueue(accessToken: String) async throws -> [String] {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/user_profiles?select=uninstall_queue") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let queue = rows?.first?["uninstall_queue"] as? [String] ?? []
        if !queue.isEmpty {
            print("[Supabase] fetchUninstallQueue → \(status) | queued: \(queue.joined(separator: ", "))")
        }
        return queue
    }

    /// Clear the uninstall queue in Supabase after processing.
    func clearUninstallQueue(accessToken: String, userId: String) async throws {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/user_profiles?on_conflict=user_id") else {
            throw URLError(.badURL)
        }
        let body: [String: Any] = [
            "user_id": userId,
            "uninstall_queue": [String](),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",             forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)",        forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("resolution=merge-duplicates",  forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status >= 300 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[Supabase] clearUninstallQueue → \(status) ERROR: \(body)")
        } else {
            print("[Supabase] clearUninstallQueue → \(status) | queue cleared")
        }
    }

    /// Fetch custom packs stored as JSONB in user_profiles.custom_packs.
    func fetchCustomPacks(accessToken: String) async throws -> [StarterPack] {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/user_profiles?select=custom_packs") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        guard let arr = rows?.first?["custom_packs"] as? [[String: Any]] else {
            print("[Supabase] fetchCustomPacks → \(status) | no custom_packs found")
            return []
        }
        let packs = arr.compactMap { dict -> StarterPack? in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String,
                  let icon = dict["icon"] as? String,
                  let appIds = dict["appIds"] as? [String] else { return nil }
            let desc = dict["description"] as? String ?? ""
            var pack = StarterPack(id: id, name: name, description: desc, icon: icon, appIds: appIds)
            pack.isCustom = true
            return pack
        }
        print("[Supabase] fetchCustomPacks → \(status) | \(packs.count) custom packs")
        return packs
    }

    /// Upsert the user's custom packs (JSONB array) to Supabase.
    func upsertCustomPacks(accessToken: String, userId: String, packs: [StarterPack]) async throws {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/user_profiles?on_conflict=user_id") else {
            throw URLError(.badURL)
        }
        let packsJson = packs.map { p -> [String: Any] in
            ["id": p.id, "name": p.name, "description": p.description, "icon": p.icon, "appIds": p.appIds]
        }
        let body: [String: Any] = [
            "user_id": userId,
            "custom_packs": packsJson,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",             forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)",        forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("resolution=merge-duplicates",  forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status >= 300 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[Supabase] upsertCustomPacks → \(status) ERROR: \(body)")
        } else {
            print("[Supabase] upsertCustomPacks → \(status) | \(packs.count) packs")
        }
    }

    /// Upsert (insert or update) the user's profile YAML in Supabase.
    func upsertProfile(accessToken: String, userId: String, yaml: String) async throws {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/user_profiles?on_conflict=user_id") else {
            throw URLError(.badURL)
        }
        let body: [String: Any] = [
            "user_id": userId,
            "profile_yaml": yaml,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",             forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)",        forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("resolution=merge-duplicates",  forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status >= 300 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[Supabase] upsertProfile → \(status) ERROR: \(body)")
        } else {
            print("[Supabase] upsertProfile → \(status) | \(yaml.count) chars")
        }
    }
}
