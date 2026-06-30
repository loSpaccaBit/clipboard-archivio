# i18n — Enterprise localization pipeline

## Architecture

| Layer | Path | Role |
|-------|------|------|
| Master | `strings.master.json` | Single source of truth (all locales) |
| Overlays | `locales/*.json` | Per-locale translator deliverables |
| Catalog | `ClipboardArchivio/Resources/Localizable.xcstrings` | Xcode String Catalog (generated) |
| Runtime | `LocalizationManager.swift` | In-app language override + RTL |
| API | `L10n.swift` | Typed string accessors |

## Supported locales (14)

`en`, `it`, `de`, `fr`, `es`, `pt-BR`, `ja`, `zh-Hans`, `ko`, `nl`, `pl`, `ru`, `ar`, `tr`

## Workflow

```bash
# 1. Edit translator overlays in locales/de.json etc.
# 2. Rebuild catalog
python3 Scripts/i18n/build-catalog.py

# 3. Validate 100% coverage + format specifier parity (CI)
python3 Scripts/i18n/validate-i18n.py
```

## Rules for translators

- Keys are English source strings — do not change keys
- Preserve format tokens exactly: `%lld`, `%@`, `%1$@`, `%2$lld`
- Preserve keyboard symbols: `⌘`, `→`
- Arabic (`ar`) uses RTL — layout handled automatically