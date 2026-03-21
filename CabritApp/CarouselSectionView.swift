import SwiftUI

struct CarouselSectionView: View {
    let section:           HomeSection
    let isFavoriteSection: Bool
    var isPoster:          Bool = false
    var hasCustomCategories: Bool = false
    var isFavorite:        (MediaItem) -> Bool
    var onToggleFavorite:  (MediaItem) -> Void
    var onDeleteCategory:  (String)    -> Void
    var onSeeAll:          (() -> Void)?
    var onSelect:          (MediaItem) -> Void

    @EnvironmentObject private var lang: LanguageManager
    @State private var hoveredItemId: String?
    @State private var isHoveringCarousel = false
    @State private var scrollPosition: Int = 0  // index of first visible item

    private let maxCarouselItems = 25
    private var items: [MediaItem] { Array(section.items.prefix(maxCarouselItems)) }
    private let pageSize = 4  // how many items to jump per arrow click

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack(spacing: 10) {
                Text(section.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text("\(section.items.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white.opacity(0.1), in: Capsule())
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                if let onSeeAll, section.items.count > 3 {
                    Button { onSeeAll() } label: {
                        HStack(spacing: 4) {
                            Text(lang.t(.seeAll))
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                if !isFavoriteSection && hasCustomCategories {
                    Button { onDeleteCategory(section.id) } label: {
                        Image(systemName: "eye.slash")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .help("\(lang.t(.hideCategory)) '\(section.title)'")
                }
            }

            // Horizontal carousel with arrow buttons
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                Button { onSelect(item) } label: {
                                    MediaCardView(
                                        title: item.title,
                                        artworkURL: item.artworkURL,
                                        isHovered: hoveredItemId == item.id,
                                        isFavorite: isFavorite(item),
                                        isPoster: isPoster
                                    )
                                }
                                .buttonStyle(.plain)
                                .onHover { hoveredItemId = $0 ? item.id : nil }
                                .id(index)
                                .contextMenu {
                                    Button {
                                        onToggleFavorite(item)
                                    } label: {
                                        Label(
                                            isFavorite(item) ? lang.t(.btnRemoveFav) : lang.t(.btnAddFav),
                                            systemImage: isFavorite(item) ? "star.slash" : "star"
                                        )
                                    }
                                    if !isFavoriteSection && hasCustomCategories {
                                        Divider()
                                        Button(role: .destructive) {
                                            onDeleteCategory(section.id)
                                        } label: {
                                            Label("\(lang.t(.hideCategory)) '\(section.title)'", systemImage: "eye.slash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                    }
                    .onChange(of: scrollPosition) { _, newPos in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(newPos, anchor: .leading)
                        }
                    }
                }

                // Arrow overlays — only visible on hover
                if isHoveringCarousel && items.count > pageSize {
                    HStack {
                        // Left arrow
                        if scrollPosition > 0 {
                            arrowButton(direction: .left) {
                                scrollPosition = max(0, scrollPosition - pageSize)
                            }
                        }

                        Spacer()

                        // Right arrow
                        if scrollPosition < items.count - pageSize {
                            arrowButton(direction: .right) {
                                scrollPosition = min(items.count - 1, scrollPosition + pageSize)
                            }
                        }
                    }
                }
            }
            .onHover { isHoveringCarousel = $0 }
        }
    }

    // MARK: - Arrow Button

    private enum ArrowDirection { case left, right }

    private func arrowButton(direction: ArrowDirection, action: @escaping () -> Void) -> some View {
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
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: isHoveringCarousel)
    }
}
