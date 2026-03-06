import SwiftUI

// MARK: - Image Cache (NSCache + Disk-backed persistent cache)

/// A shared image cache with two layers:
/// 1. In-memory NSCache for fast access during the session
/// 2. Disk cache in the app's Caches directory for persistence across launches
/// Images older than 7 days are automatically cleaned up on init.
final class ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSURL, NSImage>()
    private let session: URLSession
    private let diskCacheDir: URL
    private let maxDiskAge: TimeInterval = 7 * 24 * 3600  // 7 days

    private init() {
        memoryCache.countLimit = 500
        memoryCache.totalCostLimit = 100 * 1024 * 1024  // ~100 MB

        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity:  50 * 1024 * 1024,   // 50 MB memory
            diskCapacity:   200 * 1024 * 1024,   // 200 MB disk
            diskPath: "image_cache"
        )
        session = URLSession(configuration: config, delegate: TrustAllCertsDelegate(), delegateQueue: nil)

        // Setup disk cache directory
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheDir = caches.appendingPathComponent("iptv_image_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)

        // Clean old files on a background thread
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.cleanOldDiskCache()
        }
    }

    // MARK: - Public API

    func image(for url: URL) -> NSImage? {
        // 1. Memory cache
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }
        // 2. Disk cache
        if let diskImage = loadFromDisk(url: url) {
            memoryCache.setObject(diskImage, forKey: url as NSURL)
            return diskImage
        }
        return nil
    }

    func store(_ image: NSImage, for url: URL) {
        memoryCache.setObject(image, forKey: url as NSURL)
        saveToDisk(image, for: url)
    }

    func load(url: URL) async -> NSImage? {
        if let cached = image(for: url) { return cached }
        do {
            let (data, _) = try await session.data(from: url)
            guard let img = NSImage(data: data) else { return nil }
            let downscaled = Self.downscale(img, maxDimension: 300)
            store(downscaled, for: url)
            return downscaled
        } catch {
            return nil
        }
    }

    // MARK: - Disk operations

    private func diskPath(for url: URL) -> URL {
        let hash = url.absoluteString.utf8.reduce(into: UInt64(5381)) { hash, byte in
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)   // djb2
        }
        return diskCacheDir.appendingPathComponent("\(hash).imgcache")
    }

    private func saveToDisk(_ image: NSImage, for url: URL) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
            else { return }
            try? jpeg.write(to: self.diskPath(for: url))
        }
    }

    private func loadFromDisk(url: URL) -> NSImage? {
        let path = diskPath(for: url)
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let img = NSImage(data: data)
        else { return nil }
        // Touch file to refresh modification date (LRU behavior)
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()], ofItemAtPath: path.path
        )
        return img
    }

    private func cleanOldDiskCache() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: diskCacheDir,
                                                       includingPropertiesForKeys: [.contentModificationDateKey],
                                                       options: .skipsHiddenFiles)
        else { return }
        let cutoff = Date().addingTimeInterval(-maxDiskAge)
        for file in files {
            guard let attrs = try? fm.attributesOfItem(atPath: file.path),
                  let modDate = attrs[.modificationDate] as? Date,
                  modDate < cutoff
            else { continue }
            try? fm.removeItem(at: file)
        }
    }

    /// Resize to fit within maxDimension (preserving aspect ratio)
    private static func downscale(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = NSSize(width: round(size.width * scale), height: round(size.height * scale))
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}

// MARK: - Shared dark gradient colors for placeholders

enum AppColors {
    static let cardGradientTop    = Color(red: 0.12, green: 0.13, blue: 0.20)
    static let cardGradientBottom = Color(red: 0.06, green: 0.06, blue: 0.10)
    static let placeholderDark    = Color(red: 0.08, green: 0.08, blue: 0.14)
}

// MARK: - CachedAsyncImage (drop-in replacement for AsyncImage)

/// Displays an image from a URL with in-memory + disk caching.
/// Shows a placeholder while loading and a fallback on failure.
struct CachedAsyncImage<Placeholder: View, Fallback: View>: View {
    let url: URL?
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var fallback:    () -> Fallback

    @State private var image: NSImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
            } else if isLoading {
                placeholder()
            } else {
                fallback()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else {
            isLoading = false
            return
        }
        // Check cache synchronously first (memory + disk)
        if let cached = ImageCache.shared.image(for: url) {
            image = cached
            isLoading = false
            return
        }
        // Load from network
        isLoading = true
        image = await ImageCache.shared.load(url: url)
        isLoading = false
    }
}

// MARK: - Convenience initializer (matches common usage pattern)

extension CachedAsyncImage where Placeholder == Color, Fallback == Color {
    /// Simple initializer with default dark placeholder/fallback
    init(url: URL?) {
        self.url = url
        self.placeholder = { AppColors.cardGradientTop }
        self.fallback    = { AppColors.placeholderDark }
    }
}
