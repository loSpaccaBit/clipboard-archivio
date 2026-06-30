import AppKit
import Combine

enum ClipboardPollingMode: Equatable {
    /// Pannello aperto — risposta rapida.
    case active
    /// Menu bar in background — consumo minimo.
    case background
    /// Pausa privacy — nessun polling.
    case paused
}

@MainActor
final class ClipboardMonitor: ObservableObject {
    private var timer: Timer?
    private var lastSeenChangeCount = NSPasteboard.general.changeCount
    private var lastCapturedChangeCount = NSPasteboard.general.changeCount
    private var activationObserver: NSObjectProtocol?
    private weak var historyStore: HistoryStore?
    private(set) var mode: ClipboardPollingMode = .background

    var isRunning: Bool { timer != nil }

    var currentPollInterval: TimeInterval {
        switch mode {
        case .active: 0.2
        case .background: 0.3
        case .paused: 0
        }
    }

    func start(with store: HistoryStore) {
        historyStore = store
        lastSeenChangeCount = NSPasteboard.general.changeCount
        lastCapturedChangeCount = lastSeenChangeCount
        observeActivation()
        setMode(.background)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }

    func setMode(_ newMode: ClipboardPollingMode) {
        guard mode != newMode else { return }
        mode = newMode

        timer?.invalidate()
        timer = nil

        guard newMode != .paused else { return }

        let interval = currentPollInterval
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollClipboard()
            }
        }
        timer.tolerance = interval * 0.15
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func syncChangeCount() {
        let current = NSPasteboard.general.changeCount
        lastSeenChangeCount = current
        lastCapturedChangeCount = current
    }

    private func observeActivation() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pollClipboard()
            }
        }
    }

    private func pollClipboard() {
        let pasteboard = NSPasteboard.general
        let current = pasteboard.changeCount
        guard current != lastSeenChangeCount else { return }
        lastSeenChangeCount = current
        captureIfNeeded(from: pasteboard, observedChangeCount: current, allowRetry: true)
    }

    private func captureIfNeeded(
        from pasteboard: NSPasteboard,
        observedChangeCount: Int,
        allowRetry: Bool
    ) {
        guard observedChangeCount != lastCapturedChangeCount else { return }

        if let parsed = ClipboardParser.parse(pasteboard) {
            lastCapturedChangeCount = observedChangeCount
            historyStore?.add(parsed: parsed)
            return
        }

        guard allowRetry else { return }

        // Browsers often publish HTML before plain text — one short retry, no task cancellation.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            let pb = NSPasteboard.general
            guard pb.changeCount >= observedChangeCount else { return }
            guard pb.changeCount != lastCapturedChangeCount else { return }
            guard let parsed = ClipboardParser.parse(pb) else { return }
            lastCapturedChangeCount = pb.changeCount
            historyStore?.add(parsed: parsed)
        }
    }
}