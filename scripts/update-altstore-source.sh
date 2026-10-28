#!/bin/bash
# Пересобирает dist/altstore-source.json под текущий dist/SuperPooperApp.ipa: версия и номер сборки из
# Config/Shared.xcconfig, минимальная iOS из Info.plist внутри .ipa (18.0 из Xcode 16, 26.0 из Xcode 26), дата, размер,
# sha256, ссылки на raw.githubusercontent.com из git remote origin.
# Иконка приложения — design/icon/AppIcon-light.png; иконка источника (разработчика) — аватар аккаунта GitHub.
set -euo pipefail
cd "$(dirname "$0")/.."

IPA=dist/SuperPooperApp.ipa
[ -f "$IPA" ] || { echo "Нет $IPA — сначала scripts/make-ipa.sh" >&2; exit 1; }
REMOTE="$(git remote get-url origin | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
BRANCH="${SP_SOURCE_BRANCH:-main}"

REMOTE="$REMOTE" BRANCH="$BRANCH" IPA="$IPA" python3 - <<'PY'
import hashlib, io, json, os, plistlib, re, datetime, zipfile
cfg = open("Config/Shared.xcconfig").read()
get = lambda k: re.search(rf"^{k}\s*=\s*(\S+)", cfg, re.M).group(1)
base = f"https://raw.githubusercontent.com/{os.environ['REMOTE']}/{os.environ['BRANCH']}"
ipa = os.environ["IPA"]
data = open(ipa, "rb").read()
with zipfile.ZipFile(io.BytesIO(data)) as archive:
    info = next(name for name in archive.namelist() if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name))
    min_os = plistlib.loads(archive.read(info))["MinimumOSVersion"]
icon = f"{base}/design/icon/AppIcon-light.png"
source = {
    "name": "SuperPooperApp",
    "subtitle": "Day, tasks and habits over Obsidian",
    "description": "Personal source for SuperPooperApp.",
    "iconURL": f"https://github.com/{os.environ['REMOTE'].split('/')[0]}.png",
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
            "downloadURL": f"{base}/dist/SuperPooperApp.ipa",
            "size": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "minOSVersion": min_os,
        }],
        "appPermissions": {
            "entitlements": ["com.apple.security.application-groups"],
            "privacy": {
                "NSCalendarsFullAccessUsageDescription": "SuperPooperApp shows your anchor calendar events on the Today timeline.",
                "NSRemindersFullAccessUsageDescription": "SuperPooperApp shows timed reminders from the lists you choose.",
            },
        },
    }],
    "news": [],
}
json.dump(source, open("dist/altstore-source.json", "w"), indent=2, ensure_ascii=False)
open("dist/altstore-source.json", "a").write("\n")
PY
echo "Готово: dist/altstore-source.json → $REMOTE ($BRANCH)"
