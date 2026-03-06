import Foundation

// MARK: - Media Types

enum MediaType: String, CaseIterable, Identifiable, Codable {
    case live   = "Canales"
    case vod    = "Películas"
    case series = "Series"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .live:   return "dot.radiowaves.left.and.right"
        case .vod:    return "film"
        case .series: return "tv"
        }
    }
}

// MARK: - Credentials & Session

struct XtreamCredentials: Codable, Equatable {
    var serverURL: String = ""
    var username:  String = ""
    var password:  String = ""
}

struct XtreamSession: Equatable {
    let baseURL:  String
    let username: String
    let password: String

    var encodedUsername: String { encode(username) }
    var encodedPassword: String { encode(password) }

    init(credentials: XtreamCredentials) {
        var url = credentials.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") { url.removeLast() }
        if !url.lowercased().hasPrefix("http://") && !url.lowercased().hasPrefix("https://") {
            url = "http://" + url
        }
        self.baseURL  = url
        self.username = credentials.username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.password = credentials.password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(rawBaseURL: String, username: String, password: String) {
        self.baseURL  = rawBaseURL
        self.username = username
        self.password = password
    }

    func liveStreamURL(streamId: Int) -> URL? {
        URL(string: "\(baseURL)/live/\(encodedUsername)/\(encodedPassword)/\(streamId).m3u8")
    }
    func movieStreamURL(streamId: Int, ext: String?) -> URL? {
        let e = (ext?.isEmpty == false ? ext : "mp4") ?? "mp4"
        return URL(string: "\(baseURL)/movie/\(encodedUsername)/\(encodedPassword)/\(streamId).\(e)")
    }
    func seriesEpisodeURL(episodeId: Int, ext: String?) -> URL? {
        let e = (ext?.isEmpty == false ? ext : "mp4") ?? "mp4"
        return URL(string: "\(baseURL)/series/\(encodedUsername)/\(encodedPassword)/\(episodeId).\(e)")
    }

    private func encode(_ s: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "@+&=# %")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
}

// MARK: - Catalog Models

struct Category: Identifiable, Hashable {
    let id:   String
    let name: String
    let type: MediaType
}

struct MediaItem: Identifiable, Hashable {
    let id:                 String
    let title:              String
    let artworkURL:         URL?
    let categoryId:         String
    let type:               MediaType
    let streamId:           Int
    let containerExtension: String?
}

struct Episode: Identifiable, Hashable {
    let id:                 String
    let title:              String
    let season:             Int
    let number:             Int
    let episodeId:          Int
    let containerExtension: String?
}

struct HomeSection: Identifiable {
    let id:    String
    let title: String
    let type:  MediaType
    let items: [MediaItem]
}

struct RecentPlayback: Identifiable, Codable, Hashable {
    let id:               UUID
    let title:            String
    let urlString:        String
    let artworkURLString: String?
    let type:             MediaType
    let timestamp:        Date
    var lastPosition:     Double?   // seconds into the video
    var duration:         Double?   // total duration in seconds

    init(id: UUID = UUID(), title: String, urlString: String,
         artworkURLString: String?, type: MediaType, timestamp: Date = Date(),
         lastPosition: Double? = nil, duration: Double? = nil) {
        self.id               = id
        self.title            = title
        self.urlString        = urlString
        self.artworkURLString = artworkURLString
        self.type             = type
        self.timestamp        = timestamp
        self.lastPosition     = lastPosition
        self.duration         = duration
    }

    var url:        URL? { URL(string: urlString) }
    var artworkURL: URL? { URL(string: artworkURLString ?? "") }

    /// Progress fraction (0..1), nil if no position/duration data
    var progress: Double? {
        guard let pos = lastPosition, let dur = duration, dur > 0 else { return nil }
        return min(pos / dur, 1.0)
    }
}

struct PlayableContent: Identifiable {
    let id             = UUID()
    let title:          String
    let url:            URL
    let artworkURL:     URL?
    let type:           MediaType
    var resumePosition: Double?   // seconds to seek to on open
}

// MARK: - Favorites

struct FavoriteItem: Identifiable, Codable, Hashable {
    let id:                 String   // same as MediaItem.id
    let title:              String
    let artworkURLString:   String?
    let type:               MediaType
    let streamId:           Int
    let containerExtension: String?
    let categoryId:         String

    init(from item: MediaItem) {
        self.id                 = item.id
        self.title              = item.title
        self.artworkURLString   = item.artworkURL?.absoluteString
        self.type               = item.type
        self.streamId           = item.streamId
        self.containerExtension = item.containerExtension
        self.categoryId         = item.categoryId
    }

    var artworkURL: URL? { URL(string: artworkURLString ?? "") }

    /// Convert back to MediaItem for reuse in CarouselSectionView
    func toMediaItem() -> MediaItem {
        MediaItem(
            id:                 id,
            title:              title,
            artworkURL:         artworkURL,
            categoryId:         categoryId,
            type:               type,
            streamId:           streamId,
            containerExtension: containerExtension
        )
    }
}
// MARK: - Media Detail (from get_vod_info / get_series_info)

struct MediaDetail {
    let plot:        String?
    let rating:      String?
    let duration:    String?
    let cast:        String?
    let genre:       String?
    let releaseDate: String?
    let director:    String?
    let backdrop:    URL?
    let youtubeTrailer: String?
}

// MARK: - Custom Categories

struct CustomCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var type: MediaType
    var serverCategoryIds: [String]   // IDs of server categories grouped under this custom one
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, type: MediaType, serverCategoryIds: [String], sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.type = type
        self.serverCategoryIds = serverCategoryIds
        self.sortOrder = sortOrder
    }
}

// MARK: - Errors

enum XtreamError: LocalizedError {
    case invalidServerURL
    case authenticationFailed
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "La URL del servidor no es válida. Usa http(s)://host[:puerto]"
        case .authenticationFailed:
            return "No se pudo iniciar sesión. Revisa servidor, usuario y contraseña."
        case .malformedResponse:
            return "La respuesta del servidor no tiene el formato esperado."
        }
    }
}
