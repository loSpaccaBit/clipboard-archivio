import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: HistoryStore
    @EnvironmentObject private var privacy: PrivacyManager
    @EnvironmentObject private var vault: VaultManager
    @EnvironmentObject private var stack: StackPasteManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            topControls
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if stack.isStackMode || stack.isPasting {
                stackFooterBar
            }
        }
        .frame(width: GlassTheme.panelWidth, height: GlassTheme.panelHeight)
        .liquidGlassShell()
        .onAppear {
            store.refreshExpiredItems()
            searchFocused = false
        }
        .onChange(of: appState.focusSearchToken) { _, _ in
            focusSearchField()
        }
        .onExitCommand {
            searchFocused = false
        }
    }

    private func focusSearchField() {
        DispatchQueue.main.async {
            searchFocused = true
        }
    }

    private func dismissSearchFocus() {
        searchFocused = false
    }

    private func clearSearch() {
        store.searchQuery = ""
        searchFocused = false
    }

    @ViewBuilder
    private var mainContent: some View {
        if store.activeFilter == .vault && vault.needsAuthentication {
            vaultLockedState
        } else if store.visibleItems.isEmpty {
            emptyState
        } else {
            historyList
        }
    }

    private var topControls: some View {
        VStack(spacing: 8) {
            header
            searchBar
            if privacy.isPauseActive {
                pauseBanner
            }
            filterBar
            if stack.isStackMode {
                stackModeBanner
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private var stackModeBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.multiSelect)
                    .font(.subheadline.weight(.semibold))
                Text(L10n.multiSelectHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(L10n.close) {
                dismissSearchFocus()
                stack.finishStack()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(12)
        .nativeInsetBackground()
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "paperclip")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.clipboardTitle)
                    .font(.headline)
                Text(L10n.itemCount(store.items.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HeaderIconButton(
                systemImage: privacy.isPauseActive ? "eye" : "eye.slash",
                isActive: privacy.isPauseActive,
                help: privacy.isPauseActive ? L10n.resumeSaving : L10n.pauseSaving
            ) {
                dismissSearchFocus()
                privacy.isPauseActive ? privacy.cancelPause() : privacy.startPause()
            }

            HeaderIconButton(
                systemImage: stack.isStackMode ? "square.stack.3d.up.fill" : "square.stack.3d.up",
                isActive: stack.isStackMode,
                help: L10n.multiSelectHelp
            ) {
                dismissSearchFocus()
                if stack.isStackMode {
                    stack.finishStack()
                } else {
                    stack.toggleStackMode()
                }
            }

            HeaderIconButton(
                systemImage: "gearshape",
                help: L10n.Settings.preferences
            ) {
                dismissSearchFocus()
                appState.openPreferences()
            }
        }
        .padding(.top, 4)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundStyle(searchFocused ? Color.accentColor : .secondary)
                .accessibilityHidden(true)

            TextField(L10n.searchPlaceholder, text: $store.searchQuery)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($searchFocused)

            if !store.searchQuery.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.clearSearch)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: GlassTheme.insetRadius, style: .continuous)
                .fill(Color.primary.opacity(searchFocused ? 0.09 : 0.05))
        }
        .overlay {
            RoundedRectangle(cornerRadius: GlassTheme.insetRadius, style: .continuous)
                .strokeBorder(
                    searchFocused ? Color.accentColor.opacity(0.45) : Color.clear,
                    lineWidth: 1.5
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: GlassTheme.insetRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.searchPlaceholder)
    }

    // MARK: - Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(HistoryFilter.allCases) { filter in
                    FilterChip(
                        title: filter.label,
                        systemImage: filter.systemImage,
                        isSelected: store.activeFilter == filter
                    ) {
                        dismissSearchFocus()
                        if reduceMotion {
                            store.activeFilter = filter
                        } else {
                            withAnimation(.snappy(duration: 0.2)) {
                                store.activeFilter = filter
                            }
                        }
                        if filter == .vault && vault.needsAuthentication {
                            Task { await vault.authenticate() }
                        }
                    }
                }
            }
        }
    }

    // MARK: - List

    private var historyList: some View {
        List {
            ForEach(store.groupedSections) { section in
                Section {
                    ForEach(section.items) { item in
                        ClipboardRow(item: item, searchFocused: $searchFocused)
                            .listRowInsets(EdgeInsets(
                                top: 2,
                                leading: GlassTheme.rowInset,
                                bottom: 2,
                                trailing: GlassTheme.rowInset
                            ))
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    sectionHeader(section)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 8)
    }

    private func sectionHeader(_ section: ContextSection) -> some View {
        HStack(spacing: 6) {
            Image(systemName: section.systemImage)
                .font(.caption2.weight(.semibold))
            Text(section.title.uppercased())
                .font(.caption.weight(.semibold))
            Text("\(section.items.count)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
            Spacer()
        }
        .foregroundStyle(.secondary)
        .textCase(nil)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    // MARK: - States

    private var pauseBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.savingPaused)
                    .font(.subheadline.weight(.semibold))
                if let remaining = privacy.pauseRemainingText {
                    Text(L10n.resumesIn(remaining))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(L10n.resume, action: privacy.cancelPause)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(12)
        .nativeInsetBackground()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.savingPaused)
    }

    private var vaultLockedState: some View {
        ContentUnavailableView {
            Label(L10n.vaultProtected, systemImage: "lock.shield.fill")
        } description: {
            Text(L10n.vaultTouchIDHint)
        } actions: {
            Button(L10n.unlock) { Task { await vault.authenticate() } }
                .buttonStyle(.borderedProminent)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: emptyIcon)
        } description: {
            Text(emptySubtitle)
        }
    }

    private var emptyIcon: String {
        if privacy.isPauseActive { return "eye.slash" }
        if store.activeFilter == .vault { return "lock.shield" }
        return "paperclip"
    }

    private var emptyTitle: String {
        if privacy.isPauseActive { return L10n.savingPaused }
        if !store.searchQuery.isEmpty { return L10n.noResults }
        return L10n.noClips
    }

    private var emptySubtitle: String {
        if privacy.isPauseActive { return L10n.copiesNotSaved }
        return L10n.copyToStart
    }

    // MARK: - Stack footer

    private var stackFooterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if stack.isPasting, let progress = stack.progressText {
                stackPastingFooter(progress: progress)
            } else {
                stackSelectionFooter
            }
        }
        .padding(12)
        .nativeInsetBackground()
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var stackSelectionFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.selectedCount(stack.selectedCount))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if stack.selectedCount == 0 {
                    Text(L10n.selectAtLeastOne)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 8) {
                StackActionButton(
                    title: L10n.merge,
                    subtitle: L10n.mergeSubtitle,
                    systemImage: "doc.on.doc",
                    isProminent: false,
                    isEnabled: stack.selectedCount > 0
                ) {
                    let selected = store.visibleItems.filter { stack.selectedIDs.contains($0.id) }
                    store.copyStackJoined(selected)
                    stack.finishStack()
                }

                StackActionButton(
                    title: L10n.sequential,
                    subtitle: L10n.sequentialSubtitle,
                    systemImage: "arrow.down.circle",
                    isProminent: true,
                    isEnabled: stack.selectedCount > 0
                ) {
                    stack.startStackPaste(items: store.visibleItems) { store.copyToClipboard($0) }
                }
            }
        }
    }

    private func stackPastingFooter(progress: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.pastingProgress(progress), systemImage: "arrow.down.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text(L10n.pasteThenNext)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button {
                    stack.nextInStack { store.copyToClipboard($0) }
                } label: {
                    Label(L10n.next, systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button(L10n.done, action: stack.finishStack)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
        }
    }
}

// MARK: - Stack action button

private struct StackActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isProminent: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(isProminent ? Color.white.opacity(0.85) : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: GlassTheme.insetRadius, style: .continuous)
                    .fill(backgroundFill)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .onHover { isHovered = $0 }
    }

    private var backgroundFill: Color {
        if isProminent { return isEnabled ? Color.accentColor : Color.accentColor.opacity(0.35) }
        if isHovered { return Color.primary.opacity(0.1) }
        return Color.primary.opacity(0.06)
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background {
                    Capsule(style: .continuous)
                        .fill(chipFill)
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var chipFill: Color {
        if isSelected { return Color.accentColor }
        if isHovered { return Color.primary.opacity(0.12) }
        return Color.primary.opacity(0.07)
    }
}

// MARK: - Row

struct ClipboardRow: View {
    @EnvironmentObject private var store: HistoryStore
    @EnvironmentObject private var vault: VaultManager
    @EnvironmentObject private var stack: StackPasteManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: ClipboardItem
    var searchFocused: FocusState<Bool>.Binding
    @State private var thumbnail: NSImage?
    @State private var isHovered = false

    private var isSelected: Bool { stack.selectedIDs.contains(item.id) }
    private var isMasked: Bool { item.isVaulted && !vault.isUnlocked }
    private var displayItem: ClipboardItem { store.resolved(item) }
    private var justCopied: Bool { store.lastCopiedItemID == item.id }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if stack.isStackMode {
                Toggle(isOn: selectionBinding) {
                    EmptyView()
                }
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityLabel(isSelected ? L10n.deselect : L10n.select)
                .accessibilityValue(item.preview)
            }

            thumbnailWithCopyBadge

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if item.isVaulted {
                        Image(systemName: "lock.shield.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .accessibilityLabel(L10n.inVault)
                    }
                    Text(displayItem.preview)
                        .font(.body)
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    Text(item.subtitle)
                    Text("·")
                    Text(item.relativeTime)
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .accessibilityLabel(L10n.pinnedLabel)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .animation(rowStateAnimation, value: rowStateToken)
        .sensoryFeedback(.success, trigger: justCopied)
        .contentShape(RoundedRectangle(cornerRadius: GlassTheme.cardRadius, style: .continuous))
        .onHover { isHovered = $0 }
        .onTapGesture { handleTap() }
        .listRowBackground(rowBackground)
        .onAppear {
            if !isMasked { thumbnail = store.thumbnail(for: item) }
        }
        .contextMenu { contextMenuItems }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { store.delete(item) } label: {
                Label(L10n.delete, systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button { store.togglePin(item) } label: {
                Label(item.isPinned ? L10n.unpin : L10n.pin, systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: L10n.copy) { copyItem() }
        .accessibilityValue(justCopied ? L10n.copied : "")
    }

    private var rowStateToken: String {
        "\(justCopied)-\(isHovered)-\(isSelected)"
    }

    private var rowStateAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    private var copyFeedbackAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.72)
    }

    private var rowFillColor: Color {
        if justCopied { return Color.accentColor.opacity(0.11) }
        if isHovered { return Color.primary.opacity(0.06) }
        if isSelected && stack.isStackMode { return Color.accentColor.opacity(0.07) }
        return Color.clear
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: GlassTheme.cardRadius, style: .continuous)
            .fill(rowFillColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
    }

    @ViewBuilder
    private var thumbnailWithCopyBadge: some View {
        ZStack(alignment: .bottomTrailing) {
            if isMasked {
                maskedThumbnail
            } else {
                ItemThumbnailView(item: item, image: thumbnail)
            }

            if justCopied {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white, Color.accentColor)
                    .symbolRenderingMode(.palette)
                    .symbolEffect(.bounce, value: justCopied)
                    .background(Circle().fill(.ultraThinMaterial).padding(-2))
                    .offset(x: 2, y: 2)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(copyFeedbackAnimation, value: justCopied)
    }

    private var selectionBinding: Binding<Bool> {
        Binding(
            get: { isSelected },
            set: { _ in stack.toggleSelection(item.id) }
        )
    }

    private var accessibilitySummary: String {
        var parts = [item.preview, item.subtitle, item.relativeTime]
        if item.isPinned { parts.append(L10n.pinnedLabel.lowercased()) }
        if item.isVaulted { parts.append(L10n.vault.lowercased()) }
        return parts.joined(separator: ", ")
    }

    private var maskedThumbnail: some View {
        Image(systemName: "lock.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(width: GlassTheme.thumbnailSize, height: GlassTheme.thumbnailSize)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel(L10n.protectedContent)
    }

    private func handleTap() {
        searchFocused.wrappedValue = false
        if stack.isStackMode {
            stack.toggleSelection(item.id)
            return
        }
        if item.isVaulted && vault.needsAuthentication {
            Task {
                if await vault.authenticate() { copyItem() }
            }
            return
        }
        copyItem()
    }

    private func copyItem() {
        store.copyToClipboard(item)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button(L10n.copyAgain) { copyItem() }
        if !item.isVaulted {
            Button(L10n.moveToVault) { store.moveToVault(item) }
        } else {
            Button(L10n.removeFromVault) { store.removeFromVault(item) }
        }
        Button(item.isPinned ? L10n.unpin : L10n.pin) { store.togglePin(item) }
        if displayItem.type == .file, let path = displayItem.assetPath ?? displayItem.content {
            Button(L10n.showInFinder) { revealInFinder(path: path) }
        }
        Divider()
        Button(L10n.delete, role: .destructive) { store.delete(item) }
    }

    private func revealInFinder(path: String) {
        guard let url = AssetStorage.shared.resolveFileURL(path: path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}