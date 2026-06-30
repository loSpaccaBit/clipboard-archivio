#!/usr/bin/env python3
"""CI validation: 100% locale coverage, no empty values, format parity."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

MASTER = Path(__file__).resolve().parent / "strings.master.json"
REQUIRED = [
    "en", "it", "de", "fr", "es", "pt-BR", "ja", "zh-Hans", "ko", "nl", "pl", "ru", "ar", "tr",
]
SPECIFIERS = re.compile(r"%(?:\d+\$)?[@lld]|%lld")


def main() -> int:
    if not MASTER.exists():
        print("✗ Missing strings.master.json — run build-catalog.py first")
        return 2

    data = json.loads(MASTER.read_text(encoding="utf-8"))
    strings: dict = data["strings"]
    errors: list[str] = []

    for key, row in strings.items():
        en = row.get("en", key)
        en_specs = set(SPECIFIERS.findall(en))
        for loc in REQUIRED:
            if loc not in row or not str(row[loc]).strip():
                errors.append(f"missing [{loc}] {key[:70]}")
                continue
            loc_specs = set(SPECIFIERS.findall(row[loc]))
            if loc_specs != en_specs:
                errors.append(f"specifier mismatch [{loc}] {key[:50]}: {en_specs} vs {loc_specs}")

    if errors:
        print(f"✗ i18n validation failed ({len(errors)} issues)")
        for e in errors[:30]:
            print(" ", e)
        if len(errors) > 30:
            print(f"  … and {len(errors) - 30} more")
        return 1

    print(f"✓ i18n OK — {len(strings)} keys, {len(REQUIRED)} locales, format parity verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())