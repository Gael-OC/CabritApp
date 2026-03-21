import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {

    enum AppState: Equatable {
        case loggedOut
        case loading
        case ready
        case error(String)
    }

    @Published var state: AppState       = .loggedOut
    @Published var loadingProgress: Double = 0
    @Published var loadingStatus: String   = ""
    @Published var credentials         = XtreamCredentials()
    @Published var rememberCredentials = true
    @Published var selectedType:       MediaType   = .live {
        didSet {
            UserDefaults.standard.set(selectedType.rawValue, forKey: "last_selected_type")
            // Reset cached hero when switching tabs so each tab has its own hero
            cachedHeroItem = nil
            refreshHeroIfNeeded(for: selectedType)
            // Recompute available filters for new type
            availableFilters = computeFilters(for: selectedType)
        }
    }
    @Published var searchText:         String      = ""
    @Published var cachedSearchResults: [MediaItem] = []   // cached, updated via debounce

    // Per-type sections (lazy loaded)
    @Published var liveSections:       [HomeSection] = []
    @Published var vodSections:        [HomeSection] = []
    @Published var seriesSections:     [HomeSection] = []

    // Per-type loading state (shows spinner inside HomeView, not fullscreen)
    @Published var isLoadingLive       = false
    @Published var isLoadingVod        = false
    @Published var isLoadingSeries     = false
    @Published var sectionLoadError:   String?

    // Track which types have been loaded at least once
    private var loadedTypes:           Set<MediaType> = []
    private var loadingTasks:          [MediaType: Task<Void, Never>] = []

    @Published var availableFilters:   [String] = []   // computed when sections load

    @Published var selectedPlayable:   PlayableContent?
    @Published var selectedSeries:     MediaItem?
    @Published var episodes:           [Episode]        = []
    @Published var isLoadingEpisodes   = false
    @Published var selectedItemForDetail: MediaItem?
    @Published var mediaDetail:        MediaDetail?
    @Published var continueWatching:   [RecentPlayback] = []

    @Published var customCategories:   [CustomCategory] = []
    @Published var hiddenCategoryIds:  Set<String>      = []
    @Published var favorites:          [FavoriteItem]   = []
    @Published var expandedSection:    HomeSection?             // "Ver todo" grid
    @Published var showCategoryManager = false
    @Published var activeFilters:      Set<String>      = []
    @Published var scrollToCategoryId: String?
    @Published private(set) var cachedHeroItem: MediaItem?  // stable hero to avoid flicker

    private let api              = XtreamAPIClient()
    private let credentialsStore = CredentialsStore()
    private let historyStore     = PlaybackHistoryStore()
    private let customCatStore   = CustomCategoriesStore()
    private let hiddenStore      = HiddenCategoriesStore()
    private let favoritesStore   = FavoritesStore()
    private var session:         XtreamSession?
    private var didBootstrap     = false

    init() {
        let prefs = AppPreferences.load()
        rememberCredentials = prefs.rememberCredentials
        continueWatching    = historyStore.load()
        customCategories    = customCatStore.load()
        hiddenCategoryIds   = hiddenStore.load()
        favorites           = favoritesStore.load()

        // Restore last selected type
        if let saved = UserDefaults.standard.string(forKey: "last_selected_type"),
           let type = MediaType(rawValue: saved) {
            selectedType = type
        }

        // Debounce search to avoid recalculating on every keystroke
        searchCancellable = $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                Task { @MainActor in
                    self.updateSearchResults(query: query)
                }
            }
    }

    private var searchCancellable: AnyCancellable?

    private func updateSearchResults(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cachedSearchResults = []
            return
        }
        // Normalize for diacritic-insensitive search
        let normalizedQuery = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        var seen = Set<String>()
        cachedSearchResults = filteredSectionsForType(selectedType)
            .flatMap { $0.items }
            .filter { item in
                guard seen.insert(item.id).inserted else { return false } // dedup
                let normalizedTitle = item.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                return normalizedTitle.contains(normalizedQuery)
            }
    }

    // MARK: - Bootstrap

    func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        if let saved = credentialsStore.load() {
            credentials = saved
            if rememberCredentials { await login() }
        }
    }

    // MARK: - Login / Logout

    func login() async {
        state = .loading
        loadingProgress = 0
        loadingStatus = "Conectando al servidor…"

        let creds = XtreamCredentials(
            serverURL: credentials.serverURL.trimmingCharacters(in: .whitespacesAndNewlines),
            username:  credentials.username.trimmingCharacters(in: .whitespacesAndNewlines),
            password:  credentials.password.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            let sess = try await api.login(credentials: creds)
            self.session = sess
            credentials  = creds
            if rememberCredentials { credentialsStore.save(creds) } else { credentialsStore.clear() }
            AppPreferences(rememberCredentials: rememberCredentials).save()

            // Cargar los 3 tipos al mismo tiempo
            loadingProgress = 0.15
            loadingStatus = "Cargando contenido…"
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadType(.live) }
                group.addTask { await self.loadType(.vod) }
                group.addTask { await self.loadType(.series) }
            }
            loadingProgress = 1.0
            loadingStatus = "Listo!"

            state = .ready
        } catch {
            state = .error(loginErrorMessage(from: error))
        }
    }

    func logout() {
        session          = nil
        liveSections     = []; vodSections = []; seriesSections = []
        loadedTypes      = []
        selectedPlayable = nil
        selectedSeries   = nil
        episodes         = []
        state            = .loggedOut
    }

    func forgetSavedCredentials() {
        credentialsStore.clear()
        credentials         = XtreamCredentials()
        rememberCredentials = false
        AppPreferences(rememberCredentials: false).save()
    }

    // MARK: - Lazy loading per tab

    /// Call this whenever selectedType changes or user taps Reload.
    func loadCurrentTypeIfNeeded() async {
        guard !loadedTypes.contains(selectedType) else { return }
        // Cancel any previous load for this type
        loadingTasks[selectedType]?.cancel()
        let type = selectedType
        loadingTasks[type] = Task {
            await loadType(type)
            loadingTasks[type] = nil
        }
        await loadingTasks[type]?.value
    }

    func reloadCurrentType() async {
        loadingTasks[selectedType]?.cancel()
        loadedTypes.remove(selectedType)
        availableFilters = []  // clear filters while reloading
        let type = selectedType
        loadingTasks[type] = Task {
            await loadType(type)
            loadingTasks[type] = nil
        }
        await loadingTasks[type]?.value
    }

    private func loadType(_ type: MediaType) async {
        guard let session else { return }
        setLoading(true, for: type)
        sectionLoadError = nil
        do {
            let sections = try await api.loadSections(session: session, type: type)
            setSections(sections, for: type)
            loadedTypes.insert(type)
        } catch {
            let msg: String
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    msg = "Tiempo de espera agotado. El servidor tardó demasiado."
                case .notConnectedToInternet, .networkConnectionLost:
                    msg = "Sin conexión a internet."
                case .cannotFindHost, .cannotConnectToHost:
                    msg = "No se pudo conectar al servidor."
                default:
                    msg = "Error de red: \(urlError.localizedDescription)"
                }
            } else {
                msg = error.localizedDescription
            }
            sectionLoadError = msg
        }
        setLoading(false, for: type)
    }

    private func setLoading(_ value: Bool, for type: MediaType) {
        switch type {
        case .live:   isLoadingLive   = value
        case .vod:    isLoadingVod    = value
        case .series: isLoadingSeries = value
        }
    }

    private func setSections(_ sections: [HomeSection], for type: MediaType) {
        switch type {
        case .live:   liveSections   = sections
        case .vod:    vodSections    = sections
        case .series: seriesSections = sections
        }
        // Update filters for this type when its data arrives
        if type == selectedType {
            availableFilters = computeFilters(for: type)
        }
        // Refresh cached hero whenever sections change
        refreshHeroIfNeeded(for: type)
    }

    private func refreshHeroIfNeeded(for type: MediaType) {
        // Only refresh if current type matches or hero is nil
        guard type == selectedType || cachedHeroItem == nil else { return }
        let sections = allServerSections(for: selectedType)
        let allItems = sections.flatMap { $0.items }
        guard !allItems.isEmpty else { return }

        // 1. Last watched of this type
        let typeRecents = continueWatching.filter { $0.type == selectedType }
        if let recent = typeRecents.first,
           let match = allItems.first(where: { $0.title == recent.title || recent.urlString.contains("\($0.streamId)") }) {
            cachedHeroItem = match; return
        }
        // 2. Random favorite (only set once, stays stable)
        let typeFavs = favorites.filter { $0.type == selectedType }
        if let fav = typeFavs.randomElement(),
           let match = allItems.first(where: { $0.id == fav.id }) {
            cachedHeroItem = match; return
        }
        // 3. Random item — picked once, stays stable
        if cachedHeroItem == nil {
            cachedHeroItem = sections.randomElement()?.items.randomElement() ?? allItems.first
        }
    }

    // MARK: - Category Visibility (Hide / Show)

    func toggleHideCategory(id: String) {
        if hiddenCategoryIds.contains(id) {
            hiddenCategoryIds.remove(id)
        } else {
            hiddenCategoryIds.insert(id)
        }
        hiddenStore.save(hiddenCategoryIds)
    }

    func hideCategory(id: String) {
        hiddenCategoryIds.insert(id)
        hiddenStore.save(hiddenCategoryIds)
    }

    func showCategory(id: String) {
        hiddenCategoryIds.remove(id)
        hiddenStore.save(hiddenCategoryIds)
    }

    func showAllCategories() {
        hiddenCategoryIds.removeAll()
        hiddenStore.save(hiddenCategoryIds)
    }

    func hideAllCategories(for type: MediaType) {
        let sections = allServerSections(for: type)
        for s in sections {
            hiddenCategoryIds.insert(s.id)
        }
        hiddenStore.save(hiddenCategoryIds)
    }

    func isHidden(categoryId: String) -> Bool {
        hiddenCategoryIds.contains(categoryId)
    }

    /// All raw server sections for a type (for the category manager)
    func allServerSections(for type: MediaType) -> [HomeSection] {
        switch type {
        case .live:   return liveSections
        case .vod:    return vodSections
        case .series: return seriesSections
        }
    }

    // MARK: - Custom Categories CRUD

    func addCustomCategory(name: String, type: MediaType, serverCategoryIds: [String]) {
        let maxOrder = customCategories.map(\.sortOrder).max() ?? -1
        let cat = CustomCategory(name: name, type: type, serverCategoryIds: serverCategoryIds, sortOrder: maxOrder + 1)
        customCategories.append(cat)
        customCatStore.save(customCategories)
    }

    func deleteCustomCategory(id: UUID) {
        customCategories.removeAll { $0.id == id }
        customCatStore.save(customCategories)
    }

    func updateCustomCategory(_ updated: CustomCategory) {
        if let idx = customCategories.firstIndex(where: { $0.id == updated.id }) {
            customCategories[idx] = updated
            customCatStore.save(customCategories)
        }
    }

    func customCategoriesForType(_ type: MediaType) -> [CustomCategory] {
        customCategories.filter { $0.type == type }.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Favorites

    func isFavorite(item: MediaItem) -> Bool { favorites.contains { $0.id == item.id } }

    func toggleFavorite(item: MediaItem) {
        if let index = favorites.firstIndex(where: { $0.id == item.id }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(FavoriteItem(from: item), at: 0)
        }
        favoritesStore.save(favorites)
    }

    var favoriteSection: HomeSection? {
        let items = favorites.filter { $0.type == selectedType }.map { $0.toMediaItem() }
        guard !items.isEmpty else { return nil }
        return HomeSection(id: "_favorites", title: "⭐ Favoritos", type: selectedType, items: items)
    }

    // MARK: - Sections for current type

    /// Build sections: custom categories first (merged from server sections), then visible server sections.
    func filteredSectionsForType(_ type: MediaType) -> [HomeSection] {
        let raw: [HomeSection]
        switch type {
        case .live:   raw = liveSections
        case .vod:    raw = vodSections
        case .series: raw = seriesSections
        }

        // Server sections not hidden
        let visibleServer = raw.filter { !hiddenCategoryIds.contains($0.id) }

        // Custom categories → merged sections
        let customs = customCategoriesForType(type)
        guard !customs.isEmpty else { return visibleServer }

        let customSections: [HomeSection] = customs.compactMap { custom in
            let matchingItems = raw
                .filter { section in
                    let rawId = Self.extractRawCatId(from: section.id)
                    return custom.serverCategoryIds.contains(rawId)
                }
                .flatMap { $0.items }
            guard !matchingItems.isEmpty else { return nil }
            return HomeSection(id: custom.id.uuidString, title: custom.name, type: type, items: matchingItems)
        }

        return customSections + visibleServer
    }

    /// Extract raw category ID from section ID (format: "Type-catId")
    static func extractRawCatId(from sectionId: String) -> String {
        let parts = sectionId.split(separator: "-", maxSplits: 1)
        return parts.count > 1 ? String(parts[1]) : sectionId
    }

    /// All sections for the current type (filtered by hidden).
    private var allCurrentSections: [HomeSection] {
        filteredSectionsForType(selectedType)
    }

    // MARK: - Quality Filters

    /// Known quality/tag patterns to detect in item names
    private static let knownTags = ["4K", "UHD", "FHD", "FULL HD", "HD", "SD", "H265", "HEVC", "LATINO", "ESPAÑOL", "ENGLISH"]

    private func computeFilters(for type: MediaType) -> [String] {
        let sections: [HomeSection]
        switch type {
        case .live:   sections = liveSections
        case .vod:    sections = vodSections
        case .series: sections = seriesSections
        }
        var found: Set<String> = []
        for section in sections {
            for item in section.items {
                let upper = item.title.uppercased()
                for tag in Self.knownTags where upper.contains(tag) {
                    found.insert(tag)
                }
            }
        }
        return Self.knownTags.filter { found.contains($0) }
    }

    /// Toggle a filter tag on/off.
    func toggleFilter(_ tag: String) {
        if activeFilters.contains(tag) {
            activeFilters.remove(tag)
        } else {
            activeFilters.insert(tag)
        }
    }

    /// Sections shown in carousel mode with filters applied.
    var currentSections: [HomeSection] {
        guard !isSearching else { return [] }
        let sections = allCurrentSections
        guard !activeFilters.isEmpty else { return sections }

        // Filter items within each section
        return sections.compactMap { section in
            let filtered = section.items.filter { item in
                let upper = item.title.uppercased()
                return activeFilters.contains { upper.contains($0) }
            }
            guard !filtered.isEmpty else { return nil }
            return HomeSection(id: section.id, title: section.title, type: section.type, items: filtered)
        }
    }

    /// True when search text is not empty.
    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Use cached search results (populated by debounced Combine pipeline)
    var searchResults: [MediaItem] { cachedSearchResults }

    var isLoadingCurrentType: Bool {
        switch selectedType {
        case .live:   return isLoadingLive
        case .vod:    return isLoadingVod
        case .series: return isLoadingSeries
        }
    }

    /// Smart hero: last-watched > random favorite > random item (stable, set once per type load)
    var heroItem: MediaItem? { cachedHeroItem }

    // MARK: - Playback

    func select(item: MediaItem) async {
        guard let session else { return }
        switch item.type {
        case .live:
            guard let url = session.liveStreamURL(streamId: item.streamId) else { return }
            let p = PlayableContent(title: item.title, url: url, artworkURL: item.artworkURL, type: .live)
            selectedPlayable = p
        case .vod:
            // Show detail sheet first, user taps Play from there
            mediaDetail = nil
            selectedItemForDetail = item
            mediaDetail = await api.fetchVODInfo(session: session, vodId: item.streamId)
        case .series:
            // Show detail sheet, load episodes + info concurrently
            mediaDetail = nil
            episodes = []
            isLoadingEpisodes = true
            selectedItemForDetail = item
            async let fetchedEps = api.fetchEpisodes(session: session, seriesId: item.streamId)
            async let fetchedInfo = api.fetchSeriesInfo(session: session, seriesId: item.streamId)
            do { episodes = try await fetchedEps } catch { episodes = [] }
            mediaDetail = await fetchedInfo
            isLoadingEpisodes = false
        }
    }

    func playItem(_ item: MediaItem) {
        guard let session else { return }
        switch item.type {
        case .vod:
            guard let url = session.movieStreamURL(streamId: item.streamId, ext: item.containerExtension) else { return }
            var p = PlayableContent(title: item.title, url: url, artworkURL: item.artworkURL, type: .vod)
            // Restore saved position from continue watching if available
            if let recent = continueWatching.first(where: { $0.urlString == url.absoluteString }),
               let pos = recent.lastPosition, pos > 2 {
                p.resumePosition = pos
            }
            selectedPlayable = p
        default: break
        }
    }

    func play(episode: Episode, in series: MediaItem) {
        guard let session,
              let url = session.seriesEpisodeURL(episodeId: episode.episodeId, ext: episode.containerExtension) else { return }
        var p = PlayableContent(title: "\(series.title) · S\(episode.season)E\(episode.number)",
                                url: url, artworkURL: series.artworkURL, type: .series)
        // Restore saved position from continue watching if available
        if let recent = continueWatching.first(where: { $0.urlString == url.absoluteString }),
           let pos = recent.lastPosition, pos > 2 {
            p.resumePosition = pos
        }
        selectedPlayable = p
    }

    func playRecent(_ item: RecentPlayback) {
        guard let url = item.url else { return }
        var p = PlayableContent(title: item.title, url: url, artworkURL: item.artworkURL, type: item.type)
        p.resumePosition = item.lastPosition
        selectedPlayable = p
        // Move to top without wiping position/duration
        continueWatching.removeAll { $0.id == item.id }
        continueWatching.insert(item, at: 0)
        historyStore.save(continueWatching)
    }

    /// Called when the player reports position — also pushes to continue watching after 5s
    func updatePlaybackPosition(urlString: String, position: Double, duration: Double) {
        // Only add to "continue watching" after 5 seconds of actual playback
        if position >= 5, !continueWatching.contains(where: { $0.urlString == urlString }) {
            if let playable = selectedPlayable, playable.url.absoluteString == urlString {
                pushToContinueWatching(playable)
            }
        }

        if let idx = continueWatching.firstIndex(where: { $0.urlString == urlString }) {
            // Auto-remove if watched past 95%
            if duration > 0 && (position / duration) > 0.95 {
                continueWatching.remove(at: idx)
            } else {
                continueWatching[idx].lastPosition = position
                continueWatching[idx].duration     = duration
            }
            historyStore.save(continueWatching)
        }
    }

    /// Remove a single item from continue watching
    func removeFromContinueWatching(_ item: RecentPlayback) {
        continueWatching.removeAll { $0.id == item.id }
        historyStore.save(continueWatching)
    }

    // MARK: - Private

    private func pushToContinueWatching(_ playable: PlayableContent) {
        let e = RecentPlayback(title: playable.title, urlString: playable.url.absoluteString,
                               artworkURLString: playable.artworkURL?.absoluteString, type: playable.type)
        continueWatching.removeAll { $0.title == e.title && $0.urlString == e.urlString }
        continueWatching.insert(e, at: 0)
        // Cap to 30 items in memory (same as PlaybackHistoryStore)
        if continueWatching.count > 30 { continueWatching = Array(continueWatching.prefix(30)) }
        historyStore.save(continueWatching)
    }

    private func loginErrorMessage(from error: Error?) -> String {
        guard let error else { return XtreamError.authenticationFailed.localizedDescription }
        if let xtream = error as? XtreamError {
            switch xtream {
            case .authenticationFailed: return "Usuario o contraseña incorrectos o la cuenta está inactiva."
            case .invalidServerURL:     return xtream.localizedDescription
            case .malformedResponse:    return "El servidor respondió con un formato no compatible."
            case .hostNotFound, .timeout, .connectionLost, .genericNetwork: 
                return "Error de conexión o servidor inalcanzable."
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotFindHost, .dnsLookupFailed: return "No se encontró el servidor. Revisa la URL."
            case .timedOut:                          return "Tiempo de espera agotado."
            case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                                                     return "No se pudo conectar al servidor."
            default: return urlError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
