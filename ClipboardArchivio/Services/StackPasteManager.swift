import Foundation
import AppKit

@MainActor
final class StackPasteManager: ObservableObject {
    @Published private(set) var isStackMode = false
    @Published var selectedIDs: Set<UUID> = []
    @Published private(set) var queue: [ClipboardItem] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var isPasting = false

    var selectedCount: Int { selectedIDs.count }

    var progressText: String? {
        guard isPasting, !queue.isEmpty else { return nil }
        return L10n.stackProgress(currentIndex + 1, queue.count)
    }

    func toggleStackMode() {
        isStackMode.toggle()
        if !isStackMode {
            selectedIDs.removeAll()
        }
    }

    func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    func startStackPaste(items: [ClipboardItem], copyHandler: (ClipboardItem) -> Void) {
        let ordered = items.filter { selectedIDs.contains($0.id) }
        guard !ordered.isEmpty else { return }
        queue = ordered
        currentIndex = 0
        isPasting = true
        copyHandler(ordered[0])
    }

    func nextInStack(copyHandler: (ClipboardItem) -> Void) {
        guard isPasting, currentIndex + 1 < queue.count else {
            finishStack()
            return
        }
        currentIndex += 1
        copyHandler(queue[currentIndex])
    }

    func finishStack() {
        isPasting = false
        queue = []
        currentIndex = 0
        isStackMode = false
        selectedIDs.removeAll()
    }
}