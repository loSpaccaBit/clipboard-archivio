import Foundation
import Combine

@MainActor
final class PrivacyManager: ObservableObject {
    @Published private(set) var isPauseActive = false
    @Published private(set) var pauseEndsAt: Date?
    @Published var pauseDurationMinutes: Int = 10

    private var timer: Timer?

    var shouldSaveClipboard: Bool { !isPauseActive }

    var pauseRemainingText: String? {
        guard let end = pauseEndsAt, isPauseActive else { return nil }
        let remaining = max(0, Int(end.timeIntervalSinceNow))
        let minutes = remaining / 60
        let seconds = remaining % 60
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }

    func startPause(minutes: Int? = nil) {
        let duration = minutes ?? pauseDurationMinutes
        pauseDurationMinutes = duration
        pauseEndsAt = Date().addingTimeInterval(TimeInterval(duration * 60))
        isPauseActive = true
        onPauseStateChanged?(true)
        startTimer()
    }

    func cancelPause() {
        guard isPauseActive else { return }
        isPauseActive = false
        pauseEndsAt = nil
        timer?.invalidate()
        timer = nil
        onPauseStateChanged?(false)
    }

    var onPauseStateChanged: ((Bool) -> Void)?

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        timer?.tolerance = 0.2
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        guard let end = pauseEndsAt else {
            cancelPause()
            return
        }
        if Date() >= end {
            cancelPause()
        } else {
            objectWillChange.send()
        }
    }
}