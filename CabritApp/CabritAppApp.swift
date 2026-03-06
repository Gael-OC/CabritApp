import SwiftUI

@main
struct CabritAppApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
                .frame(minWidth: 1000, minHeight: 650)
                .preferredColorScheme(.dark)          // ← FORCE DARK MODE EVERYWHERE
                .background(WindowConfigurator())
        }
    }
}

/// Configures NSWindow: dark appearance, dark background, dark titlebar
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.11, alpha: 1)
            window.isOpaque = true
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.appearance = NSAppearance(named: .darkAqua)
            window.styleMask.insert(.fullSizeContentView)
            // Hide all scrollers globally
            Self.hideScrollers(in: window.contentView)
        }
        return view
    }

    private static func hideScrollers(in view: NSView?) {
        guard let view else { return }
        if let scrollView = view as? NSScrollView {
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.scrollerStyle = .overlay
        }
        for subview in view.subviews {
            hideScrollers(in: subview)
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.11, alpha: 1)
        nsView.window?.appearance = NSAppearance(named: .darkAqua)
        Self.hideScrollers(in: nsView.window?.contentView)
    }
}
