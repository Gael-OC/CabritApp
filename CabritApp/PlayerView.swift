import SwiftUI
import AVKit
import IOKit.pwr_mgt   // For display sleep assertion

// MARK: - PlayerView (native macOS fullscreen via NSViewRepresentable)

struct PlayerView: View {
    let content: PlayableContent
    var onClose: ((_ position: Double, _ duration: Double) -> Void)?

    var body: some View {
        AVPlayerViewRepresentable(
            url: content.url,
            resumePosition: content.resumePosition,
            onClose: onClose
        )
        .ignoresSafeArea()
        .navigationTitle(content.title)
        .frame(minWidth: 800, minHeight: 450)
    }
}

// MARK: - AVPlayerViewRepresentable
// Wraps AVPlayerView for true native macOS fullscreen.
// Uses a Coordinator to handle:
//   1. IOKit display-sleep assertion (screen won't dim)
//   2. Global key monitor for ← → arrow keys → ±10s skip (works in fullscreen too)
//   3. Saving playback position on close

struct AVPlayerViewRepresentable: NSViewRepresentable {
    let url: URL
    let resumePosition: Double?
    var onClose: ((_ position: Double, _ duration: Double) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        let player     = AVPlayer(url: url)

        playerView.player               = player
        playerView.controlsStyle        = .floating
        playerView.allowsPictureInPicturePlayback = true
        playerView.showsFullScreenToggleButton    = true

        // Store references
        context.coordinator.player  = player
        context.coordinator.onClose = onClose
        context.coordinator.inhibitScreenSleep()
        context.coordinator.installKeyMonitor()
        context.coordinator.installPeriodicSaver()

        // Resume from last position if available
        if let position = resumePosition, position > 2 {
            let seekTime = CMTimeMakeWithSeconds(position, preferredTimescale: 600)
            player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                player.play()
            }
        } else {
            player.play()
        }

        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: Coordinator) {
        coordinator.savePositionAndCleanup()
    }

    // MARK: - Coordinator

    final class Coordinator {
        var player: AVPlayer?
        var onClose: ((_ position: Double, _ duration: Double) -> Void)?

        private var sleepAssertionID: IOPMAssertionID = 0
        private var sleepAssertionActive = false
        private var keyMonitor: Any?
        private var timeObserver: Any?

        // -- Screen sleep prevention --

        func inhibitScreenSleep() {
            guard !sleepAssertionActive else { return }
            let reason = "CabritApp video playback in progress" as CFString
            let success = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &sleepAssertionID
            )
            sleepAssertionActive = (success == kIOReturnSuccess)
        }

        // -- Periodic position saving (every 5 seconds) --

        func installPeriodicSaver() {
            guard let player else { return }
            let interval = CMTimeMakeWithSeconds(5, preferredTimescale: 1)
            timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                guard let self,
                      let player = self.player,
                      let currentItem = player.currentItem else { return }
                let pos = CMTimeGetSeconds(time)
                let dur = CMTimeGetSeconds(currentItem.duration)
                if pos.isFinite && dur.isFinite && dur > 0 {
                    self.onClose?(pos, dur)
                }
            }
        }

        // -- Global keyboard monitor (works inside fullscreen AVPlayerView window) --

        func installKeyMonitor() {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let player = self.player else { return event }
                switch event.keyCode {
                case 123: // Left arrow → rewind 10s
                    self.skip(player: player, by: -10)
                    return nil
                case 124: // Right arrow → forward 10s
                    self.skip(player: player, by: 10)
                    return nil
                default:
                    return event
                }
            }
        }

        private func skip(player: AVPlayer, by seconds: Double) {
            guard let currentItem = player.currentItem else { return }
            let current  = player.currentTime()
            let duration = currentItem.duration
            let target   = CMTimeAdd(current, CMTimeMakeWithSeconds(seconds, preferredTimescale: 600))

            if target < .zero {
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            } else if duration.isValid && !duration.isIndefinite && target > duration {
                player.seek(to: duration, toleranceBefore: .zero, toleranceAfter: .zero)
            } else {
                player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }

        // -- Save position & Cleanup --

        func savePositionAndCleanup() {
            if let player {
                let pos = CMTimeGetSeconds(player.currentTime())
                let dur = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
                if pos.isFinite && dur.isFinite && dur > 0 {
                    onClose?(pos, dur)
                }
            }
            cleanup()
        }

        private func cleanup() {
            // Remove periodic observer before releasing player
            if let observer = timeObserver, let player {
                player.removeTimeObserver(observer)
                timeObserver = nil
            }

            player?.pause()
            player = nil

            if sleepAssertionActive {
                IOPMAssertionRelease(sleepAssertionID)
                sleepAssertionActive = false
            }

            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }

        deinit {
            cleanup()
        }
    }
}
