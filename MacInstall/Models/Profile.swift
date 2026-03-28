import Foundation

struct StarterPack: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let appIds: [String]
    var isCustom: Bool = false

    var appCount: Int { appIds.count }

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, appIds
        // isCustom is NOT persisted — it's set by the caller
    }
}

let starterPacks: [StarterPack] = [
    StarterPack(
        id: "developer",
        name: "Developer Setup",
        description: "Everything you need to build software — editor, terminal, containers, and essential tools.",
        icon: "hammer.fill",
        appIds: ["visual-studio-code", "iterm2", "docker", "tableplus", "postman", "github", "rectangle", "1password", "raycast", "warp", "cursor"]
    ),
    StarterPack(
        id: "designer",
        name: "Designer Setup",
        description: "Professional design tools for UI/UX, graphics, and visual work.",
        icon: "paintbrush.fill",
        appIds: ["figma", "sketch", "cleanshot", "imageoptim", "rectangle", "1password", "raycast", "canva", "obsidian"]
    ),
    StarterPack(
        id: "content-creator",
        name: "Content Creator",
        description: "Record, edit, and publish videos, podcasts, and creative content.",
        icon: "video.fill",
        appIds: ["obs", "loom", "davinci-resolve", "handbrake", "iina", "notion", "canva", "rectangle", "1password"]
    ),
    StarterPack(
        id: "data-science",
        name: "Data Science",
        description: "Analyze data, build models, and visualize insights.",
        icon: "chart.bar.fill",
        appIds: ["visual-studio-code", "docker", "tableplus", "obsidian", "rectangle", "1password", "raycast", "jupyter", "rstudio"]
    )
]
