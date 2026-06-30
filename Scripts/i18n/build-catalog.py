#!/usr/bin/env python3
"""Enterprise i18n pipeline: merge master + locale overlays → Localizable.xcstrings."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCALES_DIR = Path(__file__).resolve().parent / "locales"
XCSTRINGS_PATH = ROOT / "ClipboardArchivio/Resources/Localizable.xcstrings"
MASTER_PATH = Path(__file__).resolve().parent / "strings.master.json"
RESOURCES_MASTER_PATH = ROOT / "ClipboardArchivio/Resources/strings.master.json"

SUPPORTED_LOCALES = [
    "en", "it", "de", "fr", "es", "pt-BR", "ja", "zh-Hans", "ko", "nl", "pl", "ru", "ar", "tr",
]


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def build_master_from_xcstrings() -> dict[str, dict[str, str]]:
    cat = load_json(XCSTRINGS_PATH)
    master: dict[str, dict[str, str]] = {}
    for key, entry in cat["strings"].items():
        row: dict[str, str] = {}
        for loc, data in entry.get("localizations", {}).items():
            row[loc] = data["stringUnit"]["value"]
        if "en" not in row:
            row["en"] = key
        master[key] = row
    return master


def merge_locale_overlays(master: dict[str, dict[str, str]]) -> dict[str, dict[str, str]]:
    for code in SUPPORTED_LOCALES:
        overlay_path = LOCALES_DIR / f"{code}.json"
        if not overlay_path.exists():
            continue
        overlay = load_json(overlay_path)
        for key, value in overlay.items():
            master.setdefault(key, {"en": key})
            master[key][code] = value
    return master


def fill_missing(master: dict[str, dict[str, str]]) -> list[str]:
    warnings: list[str] = []
    for key, row in sorted(master.items()):
        for code in SUPPORTED_LOCALES:
            if code not in row or not row[code]:
                row[code] = row.get("en", key)
                warnings.append(f"fallback {code}: {key[:60]}")
    return warnings


def write_xcstrings(master: dict[str, dict[str, str]]) -> None:
    strings: dict = {}
    for key, row in sorted(master.items()):
        localizations = {}
        for code in SUPPORTED_LOCALES:
            localizations[code] = {
                "stringUnit": {
                    "state": "translated",
                    "value": row[code],
                }
            }
        strings[key] = {
            "extractionState": "manual",
            "localizations": localizations,
        }

    catalog = {
        "sourceLanguage": "en",
        "strings": strings,
        "version": "1.0",
    }
    save_json(XCSTRINGS_PATH, catalog)


def write_master(master: dict[str, dict[str, str]]) -> None:
    payload = {
        "version": 1,
        "sourceLocale": "en",
        "locales": SUPPORTED_LOCALES,
        "strings": master,
    }
    save_json(MASTER_PATH, payload)
    save_json(RESOURCES_MASTER_PATH, payload)


def main() -> int:
    master = build_master_from_xcstrings()
    master = merge_locale_overlays(master)

    # Ensure new language UI keys exist
    new_keys = {
        "Language": "Language",
        "App language": "App language",
        "Follow System": "Follow System",
        "Developer": "Developer",
        "License": "License",
        "All rights reserved. Commercial redistribution is prohibited without written permission.": (
            "All rights reserved. Commercial redistribution is prohibited without written permission."
        ),
        "Copyright © %1$lld %2$@": "Copyright © %1$lld %2$@",
        "Choose the language for Appunti Archivio. Restart the panel to apply in some views.": (
            "Choose the language for Appunti Archivio. Restart the panel to apply in some views."
        ),
    }
    for key, en in new_keys.items():
        master.setdefault(key, {"en": en})

    warnings = fill_missing(master)
    write_master(master)
    write_xcstrings(master)

    print(f"✓ Catalog: {len(master)} keys × {len(SUPPORTED_LOCALES)} locales")
    print(f"✓ Wrote {XCSTRINGS_PATH.relative_to(ROOT)}")
    print(f"✓ Wrote {MASTER_PATH.relative_to(ROOT)}")
    if warnings:
        print(f"⚠ {len(warnings)} fallbacks to English (add overlays in locales/)")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())