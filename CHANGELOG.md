# Changelog

All notable changes to **Appunti Archivio** are documented here.  
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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

[1.5.1]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.4.7...v1.5.0
[1.4.7]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.4.6...v1.4.7
[1.4.6]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.4.5...v1.4.6
[1.4.5]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.4.4...v1.4.5
[1.4.4]: https://github.com/loSpaccaBit/clipboard-archivio/compare/v1.0.0...v1.4.4
[1.0.0]: https://github.com/loSpaccaBit/clipboard-archivio/releases/tag/v1.0.0