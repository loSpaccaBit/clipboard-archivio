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
    private var lastChangeCount = NSPasteboard.general.changeCount
    private weak var historyStore: HistoryStore?
    private(set) var mode: ClipboardPollingMode = .background

    var isRunning: Bool { timer != nil }

    var currentPollInterval: TimeInterval {
        switch mode {
        case .active: 0.6
        case .background: 2.0
        case .paused: 0
        }
    }

    func start(with store: HistoryStore) {
        historyStore = store
        lastChangeCount = NSPasteboard.general.changeCount
        setMode(.background)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
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
                self?.checkClipboard()
            }
        }
        timer.tolerance = interval * 0.25
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func syncChangeCount() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let parsed = ClipboardParser.parse(pasteboard) else { return }
        historyStore?.add(parsed: parsed)
    }
}