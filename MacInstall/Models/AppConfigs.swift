import Foundation

struct ConfigPath {
    let key: String         // unique key per app, e.g. "settings"
    let path: String        // absolute or ~ path
    let description: String
    let isSensitive: Bool   // if true, warn user before capturing

    var resolvedPath: String {
        path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: resolvedPath)
    }
}

/// Per-app config paths. Key is CatalogApp.id.
let appConfigPaths: [String: [ConfigPath]] = [
    "visual-studio-code": [
        ConfigPath(key: "settings", path: "~/Library/Application Support/Code/User/settings.json", description: "Editor settings", isSensitive: false),
        ConfigPath(key: "keybindings", path: "~/Library/Application Support/Code/User/keybindings.json", description: "Keyboard shortcuts", isSensitive: false),
    ],
    "cursor": [
        ConfigPath(key: "settings", path: "~/Library/Application Support/Cursor/User/settings.json", description: "Editor settings", isSensitive: false),
        ConfigPath(key: "keybindings", path: "~/Library/Application Support/Cursor/User/keybindings.json", description: "Keyboard shortcuts", isSensitive: false),
    ],
    "iterm2": [
        ConfigPath(key: "prefs", path: "~/Library/Preferences/com.googlecode.iterm2.plist", description: "iTerm2 preferences", isSensitive: false),
    ],
    "warp": [
        ConfigPath(key: "keybindings", path: "~/.warp/keybindings.yaml", description: "Custom keybindings", isSensitive: false),
        ConfigPath(key: "prefs", path: "~/.warp/user_preferences.yaml", description: "User preferences", isSensitive: false),
    ],
    "rectangle": [
        ConfigPath(key: "prefs", path: "~/Library/Preferences/com.knollsoft.Rectangle.plist", description: "Window snapping rules", isSensitive: false),
    ],
    "raycast": [
        ConfigPath(key: "prefs", path: "~/Library/Preferences/com.raycast.macos.plist", description: "Raycast preferences", isSensitive: false),
    ],
    "git": [
        ConfigPath(key: "gitconfig", path: "~/.gitconfig", description: "Git config (name, email, aliases)", isSensitive: true),
        ConfigPath(key: "gitignore", path: "~/.gitignore_global", description: "Global gitignore patterns", isSensitive: false),
    ],
    "sublime": [
        ConfigPath(key: "settings", path: "~/Library/Application Support/Sublime Text/Packages/User/Preferences.sublime-settings", description: "Sublime Text settings", isSensitive: false),
    ],
    "bettertouchtool": [
        ConfigPath(key: "prefs", path: "~/Library/Application Support/BetterTouchTool/bttdata2", description: "BTT gestures & shortcuts", isSensitive: false),
    ],
    "obsidian": [
        ConfigPath(key: "config", path: "~/Library/Application Support/obsidian/obsidian.json", description: "Vault list & app settings", isSensitive: false),
    ],
    "vim": [
        ConfigPath(key: "vimrc", path: "~/.vimrc", description: "Vim config", isSensitive: false),
    ],
]
