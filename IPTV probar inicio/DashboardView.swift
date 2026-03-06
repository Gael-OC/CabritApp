import SwiftUI

// MARK: - HomeView — Apple TV-inspired dark UI with sidebar

struct HomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    // Unified dark palette — matches window + sidebar + titlebar
    private let bgTop    = Color(red: 0.07, green: 0.07, blue: 0.11)
    private let bgBottom = Color(red: 0.03, green: 0.03, blue: 0.05)

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(180)
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.prominentDetail)
        .toolbarBackground(.hidden, for: .windowToolbar)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $viewModel.selectedType) {
            Section {
                ForEach(MediaType.allCases) { type in
                    Label(type.rawValue, systemImage: type.systemImage)
                        .tag(type)
                        .font(.body.weight(.medium))
                }
            } header: {
                Text("Contenido").font(.caption.weight(.semibold))
            }

            Section {
                Button { Task { await viewModel.reloadCurrentType() } } label: {
                    Label("Recargar", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                }

                Button { viewModel.showCategoryManager = true } label: {
                    Label("Gestionar", systemImage: "folder.badge.gear")
                        .font(.subheadline)
                }
            } header: {
                Text("Acciones").font(.caption.weight(.semibold))
            }

            // Category list for quick navigation
            if !viewModel.currentSections.isEmpty {
                Section {
                    ForEach(viewModel.currentSections) { section in
                        Button {
                            viewModel.scrollToCategoryId = section.id
                        } label: {
                            HStack {
                                Text(section.title)
                                    .lineLimit(1)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(section.items.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.35))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.08), in: Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Categorías").font(.caption.weight(.semibold))
                }
            }

            Section {
                Button { viewModel.logout() } label: {
                    Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline)
                }
                Button {
                    viewModel.forgetSavedCredentials()
                    viewModel.logout()
                } label: {
                    Label("Olvidar cuenta", systemImage: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Usuario").font(.caption.weight(.semibold))
            }
        }
        .listStyle(.sidebar)
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.11),
                         Color(red: 0.04, green: 0.04, blue: 0.07)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .navigationTitle("IPTV")
    }

    // MARK: - Detail Content

    private var detailContent: some View {
        ZStack {
            // Full-bleed dark gradient background
            LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        topBar

                        if viewModel.isLoadingCurrentType {
                            loadingView
                        } else if let error = viewModel.sectionLoadError {
                            errorBanner(error)
                        } else if viewModel.isSearching {
                            searchResultsView
                        } else if viewModel.currentSections.isEmpty && viewModel.favoriteSection == nil {
                            emptyView
                        } else {
                            contentBody
                        }
                    }
                    .padding(28)
                    .padding(.bottom, 24)
                    .id(viewModel.selectedType)     // force re-render on tab change
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.selectedType)
                .onChange(of: viewModel.scrollToCategoryId) { _, newId in
                    guard let id = newId else { return }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(id, anchor: .top)
                    }
                    // Reset after scroll
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewModel.scrollToCategoryId = nil
                    }
                }
            }
        }
        .onChange(of: viewModel.selectedType) { _, _ in
            Task { await viewModel.loadCurrentTypeIfNeeded() }
        }
        .task { await viewModel.loadCurrentTypeIfNeeded() }
        .sheet(item: $viewModel.selectedPlayable) { playable in
            let urlString = playable.url.absoluteString
            PlayerView(content: playable) { position, duration in
                viewModel.updatePlaybackPosition(urlString: urlString, position: position, duration: duration)
            }
        }
        .sheet(item: $viewModel.expandedSection) { section in
            CategoryGridView(section: section)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.showCategoryManager) {
            CategoryManagerView()
                .environmentObject(viewModel)
        }
        .sheet(item: $viewModel.selectedItemForDetail) { item in
            ContentDetailView(item: item)
                .environmentObject(viewModel)
        }
    }

    // MARK: - Top bar (title + search)

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(typeTitle)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(typeSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                // Custom search bar matching app palette
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.45))
                        .font(.system(size: 13))

                    TextField("Buscar…", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)

                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.4))
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(width: 230)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                .contentShape(Rectangle())
            }

            // Filter chips (only shown when filters are available)
            if !viewModel.availableFilters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.availableFilters, id: \.self) { tag in
                            let isActive = viewModel.activeFilters.contains(tag)
                            Button { viewModel.toggleFilter(tag) } label: {
                                Text(tag)
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        isActive
                                            ? Color(red: 0.35, green: 0.45, blue: 1.0).opacity(0.8)
                                            : Color.white.opacity(0.08),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(isActive ? .white : .white.opacity(0.5))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        if !viewModel.activeFilters.isEmpty {
                            Button {
                                viewModel.activeFilters.removeAll()
                            } label: {
                                Text("Limpiar")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.orange.opacity(0.7))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Content body

    @ViewBuilder
    private var contentBody: some View {
        if let hero = viewModel.heroItem {
            HeroBannerView(item: hero, type: viewModel.selectedType) {
                Task { await viewModel.select(item: hero) }
            } onFavorite: {
                viewModel.toggleFavorite(item: hero)
            } isFavorite: {
                viewModel.isFavorite(item: hero)
            }
        }

        if !filteredContinueWatching.isEmpty {
            ContinueWatchingSectionView(items: filteredContinueWatching) { item in
                viewModel.playRecent(item)
            } onRemove: { item in
                viewModel.removeFromContinueWatching(item)
            }
        }

        if let favSection = viewModel.favoriteSection {
            CarouselSectionView(
                section: favSection, isFavoriteSection: true,
                isPoster: viewModel.selectedType != .live,
                isFavorite: { viewModel.isFavorite(item: $0) },
                onToggleFavorite: { viewModel.toggleFavorite(item: $0) },
                onDeleteCategory: { _ in }
            ) { item in Task { await viewModel.select(item: item) } }
        }

        ForEach(viewModel.currentSections) { section in
            CarouselSectionView(
                section: section, isFavoriteSection: false,
                isPoster: viewModel.selectedType != .live,
                hasCustomCategories: true,
                isFavorite: { viewModel.isFavorite(item: $0) },
                onToggleFavorite: { viewModel.toggleFavorite(item: $0) },
                onDeleteCategory: { viewModel.toggleHideCategory(id: $0) },
                onSeeAll: { viewModel.expandedSection = section }
            ) { item in Task { await viewModel.select(item: item) } }
            .id(section.id)
        }
    }

    // MARK: - Search results (global flat grid)

    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(viewModel.searchResults.count) resultados")
                .font(.title3.bold())
                .foregroundStyle(.white)

            if viewModel.searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Sin resultados para \"\(viewModel.searchText)\"")
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                ItemsGridView(items: viewModel.searchResults,
                              isPoster: viewModel.selectedType != .live) { item in
                    Task { await viewModel.select(item: item) }
                } isFavorite: { viewModel.isFavorite(item: $0) }
                  toggleFavorite: { viewModel.toggleFavorite(item: $0) }
            }
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2).tint(.white)
            Text("Cargando \(viewModel.selectedType.rawValue.lowercased())…")
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity).padding(.top, 100)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray").font(.system(size: 48)).foregroundStyle(.white.opacity(0.15))
            Text("Sin contenido").font(.title3.bold()).foregroundStyle(.white.opacity(0.3))
            Text("Prueba recargar.").foregroundStyle(.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity).padding(.top, 100)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange.opacity(0.7))

            Text("Error al cargar")
                .font(.title3.bold())
                .foregroundStyle(.white.opacity(0.7))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button {
                Task { await viewModel.reloadCurrentType() }
            } label: {
                Label("Reintentar", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.35, green: 0.45, blue: 1.0))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Helpers

    private var filteredContinueWatching: [RecentPlayback] {
        viewModel.continueWatching.filter { $0.type == viewModel.selectedType }
    }

    private var typeTitle: String {
        switch viewModel.selectedType {
        case .live:   return "Canales"
        case .vod:    return "Películas"
        case .series: return "Series"
        }
    }

    private var typeSubtitle: String {
        switch viewModel.selectedType {
        case .live:   return "Televisión en vivo"
        case .vod:    return "Películas a demanda"
        case .series: return "Series y episodios"
        }
    }
}

// MARK: - Hero Banner

struct HeroBannerView: View {
    let item:       MediaItem
    let type:       MediaType
    var onPlay:     () -> Void
    var onFavorite: () -> Void
    var isFavorite: () -> Bool
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: item.artworkURL) {
                LinearGradient(
                    colors: [AppColors.cardGradientTop, AppColors.cardGradientBottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            } fallback: {
                LinearGradient(
                    colors: [AppColors.cardGradientTop, AppColors.cardGradientBottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
            .scaledToFill()
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            LinearGradient(
                stops: [.init(color: .clear, location: 0.2),
                        .init(color: .black.opacity(0.92), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 10) {
                Label(type.rawValue, systemImage: type.systemImage)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.15), in: Capsule())
                    .foregroundStyle(.white.opacity(0.85))

                Text(item.title)
                    .font(.system(size: 28, weight: .bold)).lineLimit(2)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Button { onPlay() } label: {
                        Label("Reproducir", systemImage: "play.fill")
                            .font(.headline)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)

                    Button { onFavorite() } label: {
                        Image(systemName: isFavorite() ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(isFavorite() ? .yellow : .white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isHovering ? 1.005 : 1)
        .shadow(color: .black.opacity(0.5), radius: isHovering ? 18 : 8, y: 6)
        .animation(.easeOut(duration: 0.2), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Continue Watching

struct ContinueWatchingSectionView: View {
    let items: [RecentPlayback]
    var onSelect: (RecentPlayback) -> Void
    var onRemove: (RecentPlayback) -> Void
    @State private var hoveredId: UUID?
    @State private var isHoveringCarousel = false
    @State private var scrollPosition: Int = 0
    private let pageSize = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continuar viendo")
                .font(.title3.bold()).foregroundStyle(.white)

            ZStack {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                Button { onSelect(item) } label: {
                                    VStack(spacing: 0) {
                                        ZStack(alignment: .topTrailing) {
                                            MediaCardView(title: item.title, artworkURL: item.artworkURL,
                                                          isHovered: hoveredId == item.id)

                                            // Time badge in top-right corner (doesn't overlap title)
                                            if let pos = item.lastPosition, pos > 0 {
                                                Text(timeLabel(position: pos, duration: item.duration))
                                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                                                    .padding(6)
                                            }
                                        }

                                        // Progress bar below the card
                                        if let progress = item.progress, progress > 0.01 {
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    Rectangle()
                                                        .fill(.white.opacity(0.15))
                                                    Rectangle()
                                                        .fill(LinearGradient(
                                                            colors: [Color(red: 0.35, green: 0.45, blue: 1.0), Color(red: 0.55, green: 0.35, blue: 1.0)],
                                                            startPoint: .leading, endPoint: .trailing
                                                        ))
                                                        .frame(width: geo.size.width * progress)
                                                }
                                            }
                                            .frame(height: 3)
                                            .clipShape(RoundedRectangle(cornerRadius: 2))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .onHover { hoveredId = $0 ? item.id : nil }
                                .id(index)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        onRemove(item)
                                    } label: {
                                        Label("Quitar de continuar viendo", systemImage: "xmark.circle")
                                    }
                                }
                            }
                        }.padding(.vertical, 6)
                    }
                    .onChange(of: scrollPosition) { _, newPos in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(newPos, anchor: .leading)
                        }
                    }
                }

                // Arrow overlays
                if isHoveringCarousel && items.count > pageSize {
                    HStack {
                        if scrollPosition > 0 {
                            carouselArrow(direction: .left) {
                                scrollPosition = max(0, scrollPosition - pageSize)
                            }
                        }
                        Spacer()
                        if scrollPosition < items.count - pageSize {
                            carouselArrow(direction: .right) {
                                scrollPosition = min(items.count - 1, scrollPosition + pageSize)
                            }
                        }
                    }
                }
            }
            .onHover { isHoveringCarousel = $0 }
        }
    }

    private enum ArrowDir { case left, right }

    private func carouselArrow(direction: ArrowDir, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.4), radius: 6)
                Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private func timeLabel(position: Double, duration: Double?) -> String {
        let pos = formatTime(position)
        if let dur = duration, dur > 0 {
            return "\(pos) / \(formatTime(dur))"
        }
        return pos
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Series Episodes (dark)

struct SeriesEpisodesView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let series: MediaItem

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingEpisodes {
                    ProgressView("Cargando episodios…")
                } else if viewModel.episodes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film").font(.system(size: 44)).foregroundStyle(.secondary)
                        Text("Sin episodios").font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.episodes) { ep in
                        Button { viewModel.play(episode: ep, in: series) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ep.title).font(.headline)
                                    Text("T\(ep.season) · E\(ep.number)").foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "play.fill")
                            }.padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(series.title)
        }
        .frame(minWidth: 680, minHeight: 520)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Media Card (poster style for VOD/Series, landscape for Live)

struct MediaCardView: View {
    let title:      String
    let artworkURL: URL?
    let isHovered:  Bool
    var isFavorite: Bool = false
    var isPoster:   Bool = false   // true for VOD/Series (vertical), false for Live (horizontal)

    private var cardWidth:  CGFloat { isPoster ? 160 : 240 }
    private var cardHeight: CGFloat { isPoster ? 240 : 140 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: artworkURL) {
                LinearGradient(
                    colors: [AppColors.cardGradientTop, AppColors.cardGradientBottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            } fallback: {
                LinearGradient(
                    colors: [AppColors.cardGradientTop, AppColors.cardGradientBottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
            .scaledToFill()
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            LinearGradient(
                stops: [.init(color: .clear, location: 0.4),
                        .init(color: .black.opacity(0.88), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(alignment: .bottom) {
                Text(title)
                    .font(isPoster ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .lineLimit(2).foregroundStyle(.white)
                Spacer()
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption).foregroundStyle(.yellow)
                }
            }
            .padding(10)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isHovered ? 1.04 : 1)
        .shadow(color: .black.opacity(isHovered ? 0.5 : 0.15), radius: isHovered ? 12 : 5, y: 5)
        .brightness(isHovered ? 0.04 : 0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Items Grid (shared between Search Results and Category Grid)

struct ItemsGridView: View {
    let items: [MediaItem]
    var isPoster: Bool = false
    var onSelect: (MediaItem) -> Void
    var isFavorite: (MediaItem) -> Bool
    var toggleFavorite: (MediaItem) -> Void

    private var columns: [GridItem] {
        isPoster
            ? [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)]
            : [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)]
    }
    @State private var hoveredId: String?

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(items) { item in
                Button { onSelect(item) } label: {
                    MediaCardView(
                        title: item.title,
                        artworkURL: item.artworkURL,
                        isHovered: hoveredId == item.id,
                        isFavorite: isFavorite(item),
                        isPoster: isPoster
                    )
                }
                .buttonStyle(.plain)
                .onHover { hoveredId = $0 ? item.id : nil }
                .contextMenu {
                    Button {
                        toggleFavorite(item)
                    } label: {
                        Label(
                            isFavorite(item) ? "Quitar de favoritos" : "Añadir a favoritos",
                            systemImage: isFavorite(item) ? "star.slash" : "star"
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Category Grid View ("Ver todo" sheet)

struct CategoryGridView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let section: HomeSection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.11).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.title)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("\(section.items.count) elementos")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Button { viewModel.expandedSection = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }

                    // Grid
                    ItemsGridView(items: section.items,
                                  isPoster: section.type != .live) { item in
                        Task { await viewModel.select(item: item) }
                    } isFavorite: { viewModel.isFavorite(item: $0) }
                      toggleFavorite: { viewModel.toggleFavorite(item: $0) }
                }
                .padding(28)
            }
        }
        .frame(minWidth: 800, minHeight: 550)
        .preferredColorScheme(.dark)
    }
}
