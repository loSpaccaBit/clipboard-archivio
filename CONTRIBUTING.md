# Contributing to Appunti Archivio

Thank you for your interest in contributing. This project is maintained by **Francesco Pio Nocerino**.

## Getting started

1. Fork the repository and clone your fork
2. Install prerequisites: Xcode 17, XcodeGen, Python 3
3. Build locally:

   ```bash
   make install
   ```

4. Create a feature branch from `main`:

   ```bash
   git checkout -b feature/your-change
   ```

## Pull request guidelines

- Keep changes focused — one logical change per PR
- Match existing Swift style (SwiftUI, `@MainActor` where appropriate)
- Run before submitting:

  ```bash
  make validate
  make build
  ```

- Update `CHANGELOG.md` under **Unreleased** (or the current version section)
- Add / update localization keys if you change user-visible strings:

  ```bash
  # Edit Scripts/i18n/locales/<locale>.json
  make i18n
  make validate
  ```

## Localization rules

- Keys are English source strings — never rename keys
- Preserve format tokens: `%lld`, `%@`, `%1$@`, `%2$lld`
- Preserve keyboard symbols: `⌘`, `⇧`
- See [Scripts/i18n/README.md](Scripts/i18n/README.md)

## Code areas

| Path | Purpose |
|------|---------|
| `ClipboardArchivio/App/` | Lifecycle, menu bar, windows |
| `ClipboardArchivio/Services/` | Business logic |
| `ClipboardArchivio/Views/` | SwiftUI |
| `Scripts/i18n/` | Translation pipeline |

## Commit messages

Use clear, imperative subjects:

```
Fix vault expiry timer on sleep
Add Dutch plural for item count
```

## Questions

Open a [GitHub Discussion](https://github.com/lospaccabit/clipboard-archivio/discussions) or an issue labeled `question`.