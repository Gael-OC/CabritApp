# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- Parallel loading of Live TV, Movies, and Series during login (~3x faster on slow servers)
- Stable hero banner per tab — no longer randomly changes on every UI update
- `CHANGELOG.md`, `CONTRIBUTING.md`, and GitHub issue templates for open-source readiness
- Technical Notes section in README documenting SSL bypass and credentials storage decisions

### Changed
- Quality filter chips are now computed as a `@Published` var (updated when data loads) instead of a side-effectful computed property
- Image downscale maximum dimension increased from 300px to 600px for sharper thumbnails on Retina displays
- All strings in `CarouselSectionView` and `ContentDetailView` are now fully localized (EN/ES) — previously some were hardcoded in Spanish

### Fixed
- "Ver todo" / "See All" button text now respects the selected language
- Right-click context menu strings in carousels now respect the selected language
- Episode count and season labels in the detail sheet now respect the selected language

---

## [1.0.0] — 2025-03-09

### Added
- Initial public release
- Xtream Codes login (server URL + username/password)
- Live TV, Movies, and Series browsing with categories
- Dark theme with poster cards and smooth animations
- Native AVKit player with PiP, fullscreen, arrow-key seeking (±10s)
- Continue Watching — saves and resumes playback position
- Favorites per media type
- Smart diacritic-insensitive, deduplicated search
- Custom categories (group multiple server categories)
- Hidden categories (per-type)
- Quality filter chips (4K, FHD, HD, etc.)
- Bilingual UI (English / Spanish) with persistent language preference
- Two-layer image cache (in-memory + disk, 7-day expiry)
- Display sleep prevention during playback (IOKit assertion)
- Exponential retry on network errors
- Auto HTTP→HTTPS upgrade when ATS blocks plain HTTP connections
