#!/bin/bash
# Пересобирает dist/altstore-source.json под текущий dist/SuperPooper.ipa: версия и номер сборки из
# Config/Shared.xcconfig, дата, размер, sha256, ссылки на raw.githubusercontent.com из git remote origin.
# Иконка приложения и иконка источника (разработчика) — design/icon/AppIcon-light.png.
set -euo pipefail
cd "$(dirname "$0")/.."

IPA=dist/SuperPooper.ipa
[ -f "$IPA" ] || { echo "Нет $IPA — сначала scripts/make-ipa.sh" >&2; exit 1; }
REMOTE="$(git remote get-url origin | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
BRANCH="${SP_SOURCE_BRANCH:-main}"

REMOTE="$REMOTE" BRANCH="$BRANCH" IPA="$IPA" python3 - <<'PY'
import hashlib, json, os, re, datetime
cfg = open("Config/Shared.xcconfig").read()
get = lambda k: re.search(rf"^{k}\s*=\s*(\S+)", cfg, re.M).group(1)
base = f"https://raw.githubusercontent.com/{os.environ['REMOTE']}/{os.environ['BRANCH']}"
ipa = os.environ["IPA"]
data = open(ipa, "rb").read()
icon = f"{base}/design/icon/AppIcon-light.png"
source = {
    "name": "SuperPooperApp",
    "subtitle": "Day, tasks and habits over Obsidian",
    "description": "Personal source for SuperPooper.",
    "iconURL": icon,
    "website": f"https://github.com/{os.environ['REMOTE']}",
    "tintColor": "#FF2D55",
    "identifier": f"{get('SP_BUNDLE_ID')}.source",
    "sourceURL": f"{base}/dist/altstore-source.json",
    "apps": [{
        "name": "SuperPooperApp",
        "bundleIdentifier": get("SP_BUNDLE_ID"),
        "developerName": "ismylvdya",
        "subtitle": "Day, tasks and habits",
        "localizedDescription": "Day, tasks and habits on top of Obsidian TaskNotes, Apple Calendar and Reminders.",
        "iconURL": icon,
        "tintColor": "#FF2D55",
        "versions": [{
            "version": get("MARKETING_VERSION"),
            "buildVersion": get("CURRENT_PROJECT_VERSION"),
            "date": datetime.date.today().isoformat(),
            "downloadURL": f"{base}/dist/SuperPooper.ipa",
            "size": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "minOSVersion": "18.0",
        }],
        "appPermissions": {
            "entitlements": ["com.apple.security.application-groups"],
            "privacy": {
                "NSCalendarsFullAccessUsageDescription": "SuperPooper shows your anchor calendar events on the Today timeline.",
                "NSRemindersFullAccessUsageDescription": "SuperPooper shows timed reminders from the lists you choose.",
            },
        },
    }],
    "news": [],
}
json.dump(source, open("dist/altstore-source.json", "w"), indent=2, ensure_ascii=False)
open("dist/altstore-source.json", "a").write("\n")
PY
echo "Готово: dist/altstore-source.json → $REMOTE ($BRANCH)"
