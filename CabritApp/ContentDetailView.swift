import SwiftUI

// MARK: - Content Detail View (VOD + Series unified info sheet)

struct ContentDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    let item: MediaItem

    private var detail: MediaDetail? { viewModel.mediaDetail }
    private var isSeries: Bool { item.type == .series }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.11).ignoresSafeArea()

            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Hero section (capped to avoid overflow)
                        heroSection(maxHeight: min(geo.size.height * 0.4, 300))

                        // Info section
                        VStack(alignment: .leading, spacing: 14) {
                            // Title + Play
                            titleAndPlayRow

                            // Plot
                            if let plot = detail?.plot, !plot.isEmpty {
                                Text(plot)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineSpacing(4)
                            }

                            // Genre chips
                            detailChips

                            // Cast & Director
                            if let cast = detail?.cast, !cast.isEmpty {
                                detailLine(icon: "person.2.fill", label: lang.t(.detailCast), value: cast)
                            }
                            if let director = detail?.director, !director.isEmpty {
                                detailLine(icon: "megaphone.fill", label: lang.t(.detailDirector), value: director)
                            }

                            // Episodes section (series only)
                            if isSeries {
                                Divider().background(Color.white.opacity(0.1)).padding(.top, 8)
                                episodesSection
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 30)
                    }
                }
            }

            // Close button (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                            .shadow(color: .black.opacity(0.5), radius: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }
                Spacer()
            }

            // Loading overlay
            if detail == nil && !isSeries {
                loadingOverlay
            }
        }
        .frame(minWidth: 550, idealWidth: 700, maxWidth: .infinity,
               minHeight: 400, idealHeight: 550, maxHeight: .infinity)
        .preferredColorScheme(.dark)
    }

    // MARK: - Title + Play Row

    private var titleAndPlayRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)

            metadataRow

            HStack(spacing: 12) {
                if isSeries {
                    // Series: no direct play, episodes below
                } else {
                    Button {
                        viewModel.selectedItemForDetail = nil
                        viewModel.playItem(item)
                    } label: {
                        Label(lang.t(.btnPlay), systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.35, green: 0.45, blue: 1.0))
                }

                // Favorite button
                Button {
                    viewModel.toggleFavorite(item: item)
                } label: {
                    Image(systemName: viewModel.isFavorite(item: item) ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(viewModel.isFavorite(item: item) ? .red : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Hero

    private func heroSection(maxHeight: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let backdrop = detail?.backdrop {
                CachedAsyncImage(url: backdrop) {
                    Color(red: 0.1, green: 0.1, blue: 0.16)
                } fallback: {
                    artworkFallback(height: maxHeight)
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxHeight: maxHeight)
                .clipped()
            } else {
                artworkFallback(height: maxHeight)
            }

            // Gradient overlay at bottom
            LinearGradient(
                colors: [.clear, Color(red: 0.07, green: 0.07, blue: 0.11)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 100)
            .frame(maxWidth: .infinity)
        }
    }

    private func artworkFallback(height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.15, blue: 0.25), Color(red: 0.07, green: 0.07, blue: 0.11)],
                startPoint: .top, endPoint: .bottom
            )
            if let url = item.artworkURL {
                CachedAsyncImage(url: url) {
                    Color.clear
                } fallback: {
                    Color.clear
                }
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: height * 0.7)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.5), radius: 12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    // MARK: - Metadata

    private var metadataRow: some View {
        HStack(spacing: 10) {
            if let year = detail?.releaseDate, !year.isEmpty {
                Text(String(year.prefix(4)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            if let duration = detail?.duration, !duration.isEmpty {
                Text(duration)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            if let rating = detail?.rating, !rating.isEmpty, rating != "0" {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow.opacity(0.8))
                    Text(rating)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.yellow.opacity(0.8))
                }
            }
            if isSeries {
                Text("\(viewModel.episodes.count) \(lang.currentLanguage == .en ? "episodes" : "episodios")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private var detailChips: some View {
        Group {
            if let genre = detail?.genre, !genre.isEmpty {
                let genres = genre.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(genres.prefix(6), id: \.self) { g in
                            Text(g)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08), in: Capsule())
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
            }
        }
    }

    private func detailLine(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.4))
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(3)
            }
        }
    }

    // MARK: - Episodes (Series)

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isLoadingEpisodes {
                HStack {
                    ProgressView().scaleEffect(0.7).tint(.white)
                    Text(lang.t(.loadingEpisodes))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 8)
            } else if viewModel.episodes.isEmpty {
                Text(lang.t(.noEpisodesTitle))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 8)
            } else {
                let seasons = Set(viewModel.episodes.map(\.season)).sorted()

                ForEach(seasons, id: \.self) { season in
                    let eps = viewModel.episodes.filter { $0.season == season }

                    DisclosureGroup {
                        LazyVStack(spacing: 2) {
                            ForEach(eps) { ep in
                                Button {
                                    viewModel.play(episode: ep, in: item)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Text("E\(ep.number)")
                                            .font(.caption.weight(.bold).monospacedDigit())
                                            .foregroundStyle(Color(red: 0.4, green: 0.5, blue: 1.0))
                                            .frame(width: 35, alignment: .leading)

                                        Text(ep.title)
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.85))
                                            .lineLimit(1)

                                        Spacer()

                                        Image(systemName: "play.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } label: {
                        HStack {
                            Text(seasons.count == 1 ? (lang.currentLanguage == .en ? "Episodes" : "Episodios") : (lang.currentLanguage == .en ? "Season \(season)" : "Temporada \(season)"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Text("\(eps.count) eps")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .tint(.white.opacity(0.5))
                }
            }
        }
    }

    // MARK: - Loading overlay

    private var loadingOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ProgressView().scaleEffect(0.8).tint(.white)
                Text(lang.currentLanguage == .en ? "Loading info…" : "Cargando info…")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }
            .padding(.bottom, 30)
        }
    }
}
