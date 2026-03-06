import Foundation

// MARK: - App Preferences

struct AppPreferences {
    var rememberCredentials: Bool

    private static let rememberKey = "remember_credentials"

    static func load() -> AppPreferences {
        let remember = UserDefaults.standard.object(forKey: rememberKey) as? Bool ?? true
        return AppPreferences(rememberCredentials: remember)
    }

    func save() {
        UserDefaults.standard.set(rememberCredentials, forKey: Self.rememberKey)
    }
}

// MARK: - Playback History

final class PlaybackHistoryStore {
    private let key      = "playback_history"
    private let maxItems = 30
    private let encoder  = JSONEncoder()
    private let decoder  = JSONDecoder()

    func load() -> [RecentPlayback] {
        guard let data  = UserDefaults.standard.data(forKey: key),
              let value = try? decoder.decode([RecentPlayback].self, from: data)
        else { return [] }
        return value.sorted(by: { $0.timestamp > $1.timestamp })
    }

    func save(_ items: [RecentPlayback]) {
        if let data = try? encoder.encode(Array(items.prefix(maxItems))) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Hidden Categories Store

final class HiddenCategoriesStore {
    private let key = "hidden_category_ids"

    func load() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(array)
    }

    func save(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: key)
    }
}

// MARK: - Custom Categories Store

final class CustomCategoriesStore {
    private let key     = "custom_categories"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() -> [CustomCategory] {
        guard let data  = UserDefaults.standard.data(forKey: key),
              let value = try? decoder.decode([CustomCategory].self, from: data)
        else { return [] }
        return value.sorted { $0.sortOrder < $1.sortOrder }
    }

    func save(_ items: [CustomCategory]) {
        if let data = try? encoder.encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Favorites Store

final class FavoritesStore {
    private let key     = "favorite_items"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() -> [FavoriteItem] {
        guard let data  = UserDefaults.standard.data(forKey: key),
              let value = try? decoder.decode([FavoriteItem].self, from: data)
        else { return [] }
        return value
    }

    func save(_ items: [FavoriteItem]) {
        if let data = try? encoder.encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Credentials Store (UserDefaults — no password prompts)

final class CredentialsStore {
    private let key     = "saved_credentials"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func save(_ credentials: XtreamCredentials) {
        if let data = try? encoder.encode(credentials) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() -> XtreamCredentials? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let creds = try? decoder.decode(XtreamCredentials.self, from: data)
        else { return nil }
        return creds
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
