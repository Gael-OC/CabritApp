import Foundation

// MARK: - XtreamAPIClient
// Uses a custom URLSession delegate to bypass SSL cert validation
// (needed for IPTV servers with self-signed or expired certs).

final class XtreamAPIClient {

    private let maxRetries = 2

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30   // 30s per request
        config.timeoutIntervalForResource = 120  // 2 min total for large loads
        return URLSession(configuration: config, delegate: TrustAllCertsDelegate(), delegateQueue: nil)
    }()

    // MARK: - Login

    func login(credentials: XtreamCredentials) async throws -> XtreamSession {
        var xtreams = XtreamSession(credentials: credentials)

        do {
            try await verifyLogin(session: xtreams)
            return xtreams
        } catch let urlError as URLError where urlError.code == .appTransportSecurityRequiresSecureConnection {
            // Transparently switch http → https if ATS blocks plain HTTP
            let httpsBase = xtreams.baseURL
                .replacingOccurrences(of: "http://", with: "https://", options: [.caseInsensitive, .anchored])
            xtreams = XtreamSession(rawBaseURL: httpsBase, username: xtreams.username, password: xtreams.password)
            try await verifyLogin(session: xtreams)
            return xtreams
        }
    }

    private func verifyLogin(session: XtreamSession) async throws {
        let urlString = "\(session.baseURL)/player_api.php?username=\(session.encodedUsername)&password=\(session.encodedPassword)"
        guard let url = URL(string: urlString) else { throw XtreamError.invalidServerURL }

        let (data, response) = try await self.session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else { throw XtreamError.malformedResponse }
        guard (200...399).contains(httpResponse.statusCode) else { throw XtreamError.authenticationFailed }

        guard let json     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userInfo = json["user_info"] as? [String: Any]
        else { throw XtreamError.malformedResponse }

        let auth   = Self.intValue(userInfo["auth"])
        let status = (userInfo["status"] as? String)?.lowercased() ?? ""
        guard auth == 1 || status == "active" || status == "enabled" else {
            throw XtreamError.authenticationFailed
        }
    }

    // MARK: - Load Sections (lazy per-tab)

    func loadSections(session: XtreamSession, type: MediaType) async throws -> [HomeSection] {
        let (catAction, streamAction): (String, String)
        switch type {
        case .live:   (catAction, streamAction) = ("get_live_categories",   "get_live_streams")
        case .vod:    (catAction, streamAction) = ("get_vod_categories",    "get_vod_streams")
        case .series: (catAction, streamAction) = ("get_series_categories", "get_series")
        }

        async let cats  = fetchCategories(session: session, action: catAction,    type: type)
        async let items = fetchMediaItems (session: session, action: streamAction, type: type)

        let categories = (try? await cats)  ?? []
        let mediaItems = (try? await items) ?? []
        return groupedSections(type: type, categories: categories, items: mediaItems)
    }

    // MARK: - Episodes

    func fetchEpisodes(session: XtreamSession, seriesId: Int) async throws -> [Episode] {
        let urlString = "\(session.baseURL)/player_api.php?username=\(session.encodedUsername)&password=\(session.encodedPassword)&action=get_series_info&series_id=\(seriesId)"
        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await self.session.data(from: url)
        guard let object     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let episodesMap = object["episodes"] as? [String: Any] else { return [] }

        var episodes: [Episode] = []
        for (seasonKey, value) in episodesMap {
            let season = Int(seasonKey) ?? 0
            guard let list = value as? [[String: Any]] else { continue }
            for (index, item) in list.enumerated() {
                guard let epId = Self.intValue(item["id"]) else { continue }
                let epNum = Self.intValue(item["episode_num"]) ?? 0
                episodes.append(Episode(
                    id:                 "ep-\(epId)",
                    title:              (item["title"] as? String) ?? (item["name"] as? String) ?? "Episodio \(epId)",
                    season:             season,
                    number:             epNum > 0 ? epNum : (index + 1),   // fallback to array index
                    episodeId:          epId,
                    containerExtension: item["container_extension"] as? String
                ))
            }
        }
        return episodes.sorted { $0.season == $1.season ? $0.number < $1.number : $0.season < $1.season }
    }

    // MARK: - Content Detail Info

    func fetchVODInfo(session sess: XtreamSession, vodId: Int) async -> MediaDetail? {
        let urlString = "\(sess.baseURL)/player_api.php?username=\(sess.encodedUsername)&password=\(sess.encodedPassword)&action=get_vod_info&vod_id=\(vodId)"
        guard let data = try? await fetch(urlString: urlString),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let info = json["info"] as? [String: Any]
        else { return nil }
        return parseMediaDetail(from: info)
    }

    func fetchSeriesInfo(session sess: XtreamSession, seriesId: Int) async -> MediaDetail? {
        let urlString = "\(sess.baseURL)/player_api.php?username=\(sess.encodedUsername)&password=\(sess.encodedPassword)&action=get_series_info&series_id=\(seriesId)"
        guard let data = try? await fetch(urlString: urlString),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let info = json["info"] as? [String: Any]
        else { return nil }
        return parseMediaDetail(from: info)
    }

    private func parseMediaDetail(from info: [String: Any]) -> MediaDetail {
        let backdrop: URL? = {
            if let urlStr = info["backdrop_path"] as? [String],
               let first = urlStr.first { return URL(string: first) }
            if let urlStr = info["backdrop_path"] as? String,
               !urlStr.isEmpty { return URL(string: urlStr) }
            if let urlStr = info["cover_big"] as? String,
               !urlStr.isEmpty { return URL(string: urlStr) }
            if let urlStr = info["cover"] as? String,
               !urlStr.isEmpty { return URL(string: urlStr) }
            return nil
        }()

        return MediaDetail(
            plot:        info["plot"] as? String ?? info["description"] as? String,
            rating:      info["rating"] as? String ?? (info["rating"] as? NSNumber)?.stringValue,
            duration:    info["duration"] as? String ?? info["runtime"] as? String,
            cast:        info["cast"] as? String ?? info["actors"] as? String,
            genre:       info["genre"] as? String ?? info["category_name"] as? String,
            releaseDate: info["releasedate"] as? String ?? info["releaseDate"] as? String ?? info["release_date"] as? String,
            director:    info["director"] as? String,
            backdrop:    backdrop,
            youtubeTrailer: info["youtube_trailer"] as? String
        )
    }


    // MARK: - Private helpers

    private func fetch(urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else { return Data() }
        var lastError: Error?
        for attempt in 0...maxRetries {
            do {
                let (data, _) = try await session.data(from: url)
                return data
            } catch {
                lastError = error
                if attempt < maxRetries {
                    // Exponential backoff: 1s, 2s
                    try? await Task.sleep(nanoseconds: UInt64((attempt + 1)) * 1_000_000_000)
                }
            }
        }
        throw lastError ?? URLError(.timedOut)
    }

    private func fetchCategories(session sess: XtreamSession, action: String, type: MediaType) async throws -> [Category] {
        let s = "\(sess.baseURL)/player_api.php?username=\(sess.encodedUsername)&password=\(sess.encodedPassword)&action=\(action)"
        let data = try await fetch(urlString: s)
        // Parse on background thread
        let t = type
        return await Task.detached(priority: .userInitiated) {
            guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [Category]() }
            return array.compactMap { obj in
                guard let id = (obj["category_id"] as? String) ?? (obj["category_id"] as? Int).map(String.init) else { return nil }
                return Category(id: id, name: (obj["category_name"] as? String) ?? "Sin nombre", type: t)
            }
        }.value
    }

    private func fetchMediaItems(session sess: XtreamSession, action: String, type: MediaType) async throws -> [MediaItem] {
        let s = "\(sess.baseURL)/player_api.php?username=\(sess.encodedUsername)&password=\(sess.encodedPassword)&action=\(action)"
        let data = try await fetch(urlString: s)
        // Parse on background thread
        let t = type
        return await Task.detached(priority: .userInitiated) {
            guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [MediaItem]() }
            return array.compactMap { obj -> MediaItem? in
                let idKey = t == .series ? "series_id" : "stream_id"
                guard let streamId = Self.intValue(obj[idKey]) else { return nil }
                let title  = (obj["name"] as? String) ?? "Sin título"
                let catId  = (obj["category_id"] as? String) ?? "uncategorized"
                let image  = t == .series ? (obj["cover"] as? String) : (obj["stream_icon"] as? String)
                return MediaItem(
                    id:                 "\(t.rawValue)-\(streamId)",
                    title:              title,
                    artworkURL:         URL(string: image ?? ""),
                    categoryId:         catId,
                    type:               t,
                    streamId:           streamId,
                    containerExtension: obj["container_extension"] as? String
                )
            }
        }.value
    }

    private func groupedSections(type: MediaType, categories: [Category], items: [MediaItem]) -> [HomeSection] {
        let nameById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        return Dictionary(grouping: items, by: { $0.categoryId })
            .map { id, items in
                HomeSection(
                    id:    "\(type.rawValue)-\(id)",
                    title: nameById[id] ?? "Destacados",
                    type:  type,
                    items: items  // skip per-category sort for faster loading
                )
            }
            .sorted { $0.title < $1.title }
    }

    private nonisolated static func intValue(_ any: Any?) -> Int? {
        switch any {
        case let v as Int:      return v
        case let v as String:   return Int(v)
        case let v as NSNumber: return v.intValue
        default:                return nil
        }
    }
}

// MARK: - TrustAllCertsDelegate
// Accepts any SSL cert so IPTV servers with self-signed/expired certs work.
// Shared across XtreamAPIClient and ImageCache.
final class TrustAllCertsDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
