# Changelog

All notable changes to **Clipboard Archive** are documented here.  
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- First-launch onboarding window after install (menu bar guide, shortcut, opens archive on continue)
- DMG **Install Clipboard Archive** app — embeds a macOS `.pkg`, runs `installer`, launches the app, and ejects the disk (onboarding on first open)

### Changed
- DMG uses standard **PKG installer** flow (enterprise / IT-compatible), not drag-to-Applications
- App icon (`AppIcon.icns`) generated from project logo
- Product renamed to **Clipboard Archive** (display name, `.app` bundle, DMG/PKG assets, landing page)
- Release assets: `Clipboard-Archive.dmg` and optional `Clipboard-Archive.pkg` (`make pkg`)

### Fixed
- CI / Release workflows: compile on GitHub runners (SDK 15) via `GLASS_SDK_FALLBACK` while local builds keep native Liquid Glass
- Landing download: native `<a download>` without JS intercept; `.nojekyll` serves hosted DMG

## [1.6.3] - 2026-06-30

### Changed
- DMG installer with **Installa Appunti Archivio.app** — launches PKG that copies the app to `/Applications`
- Landing page uses **direct download** (`releases/latest/download/Appunti-Archivio.dmg`)
- Stable release assets: `Appunti-Archivio.dmg` and `Appunti-Archivio.pkg`

## [1.6.2] - 2026-06-30

### Changed
- GitHub releases ship a **DMG** containing `Appunti Archivio.app` and an Applications shortcut (replaces `.zip`)
- `make package` and `Scripts/package-dmg.sh` for local release builds

## [1.6.1] - 2026-06-30

### Added
- SVG logo (`docs/assets/logo.svg`) in README and landing page
- Landing page at `docs/` with download section and GitHub Pages workflow

## [1.6.0] - 2026-06-30

### Changed
- License changed to **[GNU GPL v3.0 or later](https://www.gnu.org/licenses/gpl-3.0.html)** (SPDX: `GPL-3.0-or-later`)
- Full official license text in [COPYING](COPYING) (from gnu.org/licenses/gpl-3.0.txt)

## [1.5.2] - 2026-06-30

### Changed
- Adopt **[PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0)** (SPDX: `PolyForm-Noncommercial-1.0.0`) — official license, verbatim from polyformproject/polyform-licenses

## [1.5.1] - 2026-06-30

### Changed
- Replaced MIT with **proprietary license**: personal use allowed, **commercial redistribution prohibited**
- License notice shown in About section (14 locales via English fallback)

## [1.5.0] - 2026-06-30

### Added
- Developer credit: **Francesco Pio Nocerino** in About section and project metadata
- Open-source release: README, LICENSE (MIT), CONTRIBUTING, SECURITY, CI workflows
- Makefile for generate / build / install / i18n / validate
- `Developer` and copyright strings in all 14 locales

### Changed
- GitHub-ready repository structure with `.gitignore` and issue templates

## [1.4.7] - 2026-06-30

### Fixed
- Language change no longer breaks UI: preferences and archive panel close cleanly on locale switch
- Opening preferences now closes the archive panel automatically

## [1.4.6] - 2026-06-30

### Fixed
- Localization catalog format regression (mixed JSON schemas broke all translations)
- Real-time language refresh via `revision` identity and cache invalidation

## [1.4.5] - 2026-06-30

### Changed
- Finder files stored as references by default (no disk duplication)
- Materialized copies only for pin, vault, or inline/image data
- Files larger than 25 MB remain reference-only

## [1.4.4] - 2026-06-30

### Changed
- Performance: lazy panel, list caches, debounced saves, thumbnail cache
- Idle RAM reduced from ~130 MB to ~74 MB

## [1.0.0] - 2026-06-30

### Added
- Initial release: menu bar clipboard archive, vault, stack paste, 14-language i18n

[1.6.1]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.5.2...v1.6.0
[1.5.2]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.5.1...v1.5.2
[1.5.1]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.4.7...v1.5.0
[1.4.7]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.4.6...v1.4.7
[1.4.6]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.4.5...v1.4.6
[1.4.5]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.4.4...v1.4.5
[1.4.4]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.0.0...v1.4.4
[1.0.0]: https://github.com/loSpaccaBit/clipboard-archivio/releases/tag/v1.0.0