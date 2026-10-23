"""Build the app's metadata and translations without proprietary Xcode tools."""
import json
import plistlib
import sys
from pathlib import Path

app = Path(sys.argv[1])
version = sys.argv[2]
with (app / "Contents/Info.plist").open("wb") as stream:
    plistlib.dump({
        "CFBundleIdentifier": "glass.kagerou.adrafinil",
        "CFBundleExecutable": "Adrafinil",
        "CFBundleName": "Adrafinil",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": version,
        "CFBundleIconFile": "Adrafinil.icns",
        "CFBundleDevelopmentRegion": "en",
        "LSUIElement": True,
        "LSMinimumSystemVersion": "26.4",
        "NSSupportsAutomaticTermination": False,
    }, stream)

catalog = json.loads(Path("Adrafinil/Localizable.xcstrings").read_text())
translations = {}
for key, entry in catalog["strings"].items():
    for locale, localized in entry.get("localizations", {}).items():
        unit = localized.get("stringUnit")
        if unit is not None:
            translations.setdefault(locale, {})[key] = unit["value"]
for locale, strings in translations.items():
    destination = app / "Contents/Resources" / f"{locale}.lproj"
    destination.mkdir(parents=True, exist_ok=True)
    # JSON string escaping is compatible with the quoted strings in a .strings file.
    (destination / "Localizable.strings").write_text("\n".join(
        f"{json.dumps(key, ensure_ascii=False)} = {json.dumps(value, ensure_ascii=False)};"
        for key, value in sorted(strings.items())
    ) + "\n")
