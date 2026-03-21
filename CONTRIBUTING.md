# Contributing to CabritApp

Thanks for your interest in contributing! Here's everything you need to get started.

---

## Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/CabritApp.git
   cd CabritApp
   open CabritApp.xcodeproj
   ```
3. Select **My Mac** as the build target and press **Cmd+R** to build and run.

**Requirements:** macOS 14.0+ (Sonoma) · Xcode 15+

---

## Project Structure

| File | Purpose |
|------|---------|
| `AppViewModel.swift` | All business logic (login, sections, favorites, playback) |
| `XtreamService.swift` | Xtream Codes API client |
| `Models.swift` | Data models |
| `Persistence.swift` | UserDefaults-backed stores |
| `LanguageManager.swift` | EN/ES localization system |
| `DashboardView.swift` | Main UI (sidebar + content area) |
| `PlayerView.swift` | AVKit player wrapper |
| `ContentDetailView.swift` | VOD/Series detail sheet |
| `CarouselSectionView.swift` | Horizontal carousel component |
| `CachedAsyncImage.swift` | Two-layer image cache |

---

## Code Conventions

- **Architecture:** `@MainActor` ViewModel + SwiftUI views. Keep business logic in `AppViewModel`, not in views.
- **Localization:** All user-facing strings must use `LanguageManager` (`lang.t(.key)`). Never hardcode Spanish or English strings in views. Add new keys to `L10nKey` enum and provide translations in both `es` and `en` dictionaries in `LanguageManager.swift`.
- **Async:** Use `async/await`. Avoid `DispatchQueue` for data loading; use `Task` and `async let` for parallelism.
- **No third-party dependencies:** The project intentionally has zero external dependencies. Keep it that way unless there's a very strong reason.
- **Image caching:** Always use `CachedAsyncImage` instead of SwiftUI's `AsyncImage`.

---

## How to Report a Bug

Use the **Bug Report** issue template on GitHub. Please include:
- macOS version
- Server type (if known)
- Steps to reproduce
- What you expected vs. what happened

---

## How to Suggest a Feature

Use the **Feature Request** issue template. Describe the problem you're trying to solve, not just the solution.

---

## Pull Requests

1. Create a branch: `git checkout -b feature/my-improvement`
2. Make your changes following the conventions above
3. Test on a real Xtream Codes server if possible
4. Open a PR with a clear description of what changed and why

There are no automated tests yet — manual testing against a real or mock server is the main validation method.

---

## Technical Decisions Worth Knowing

- **SSL bypass:** `TrustAllCertsDelegate` accepts all SSL certs. This is intentional for IPTV compatibility. See README for details.
- **UserDefaults for credentials:** Intentionally not using Keychain to avoid OS password prompts on non-notarized builds.
- **No Combine in views:** All reactive state flows through `@Published` properties on `AppViewModel`. Combine is only used for the search debounce pipeline.
