#!/bin/bash
# Ставит актуальное приложение на подключённый айфон (по проводу или по Wi-Fi):
#   1. сверяет main с GitHub: локальный новее — push, GitHub новее — pull;
#   2. если сборка ещё под iOS 18 — переход на iOS 26 (docs/IOS26-BUILD.md), коммит и push перехода;
#   3. поднимает мост RoamRun, если айфон далеко (Tailscale); находит айфон, при необходимости будит соединение;
#   4. убирает старые профили подписи этого приложения (подпись — 7 дней с установки),
#      собирает Release и ставит поверх старого (данные остаются).
# Использование: scripts/install-iphone.sh   (другой айфон — SP_IPHONE="Имя айфона"; без моста RoamRun, напрямую по Wi-Fi — SP_DIRECT=1)
set -euo pipefail
cd "$(dirname "$0")/.."

BRANCH="main"
REMOTE="origin"
XCCONFIG="Config/Shared.xcconfig"
IOS18_LINE='IPHONEOS_DEPLOYMENT_TARGET[sdk=iphone*18*]'
DERIVED="./.build/DerivedData-phone"
APP="$DERIVED/Build/Products/Release-iphoneos/SuperPooperApp.app"
PROFILES="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
WAKE_TRIES=12
WAKE_PAUSE=5

step() { echo; echo "▶ $*"; }
notify() { /usr/bin/osascript -e "display notification \"$1\" with title \"SuperPooperApp\"" >/dev/null 2>&1 || true; }
fail() { echo "✖ $*" >&2; notify "Не установлено: $*"; exit 1; }
trap 'fail "ошибка в строке $LINENO"' ERR

# 1. Синхронизация с GitHub
step "Сверяю $BRANCH с GitHub"
[ "$(git branch --show-current)" = "$BRANCH" ] || fail "открыта ветка $(git branch --show-current), нужна $BRANCH"
git fetch --quiet "$REMOTE"
AHEAD=$(git rev-list --count "$REMOTE/$BRANCH..$BRANCH")
BEHIND=$(git rev-list --count "$BRANCH..$REMOTE/$BRANCH")
if [ "$AHEAD" -gt 0 ] && [ "$BEHIND" -gt 0 ]; then
  fail "локальный $BRANCH и GitHub разошлись ($AHEAD своих, $BEHIND чужих коммитов) — свести вручную"
elif [ "$BEHIND" -gt 0 ]; then
  echo "GitHub новее на $BEHIND коммит(ов) — pull"
  git pull --ff-only --quiet "$REMOTE" "$BRANCH" || fail "pull не прошёл (незакоммиченные правки мешают?)"
elif [ "$AHEAD" -gt 0 ]; then
  echo "Локальная версия новее на $AHEAD коммит(ов) — push"
  git push --quiet "$REMOTE" "$BRANCH"
else
  echo "Версии совпадают"
fi
git diff --quiet || echo "⚠ есть незакоммиченные правки — они попадут в сборку, но не на GitHub"

# 2. iOS 18 → iOS 26
step "Проверяю, под какую iOS сборка"
if grep -qF "$IOS18_LINE" "$XCCONFIG"; then
  XCODE_VERSION="$(xcodebuild -version)"
  XCODE_MAJOR="$(awk 'NR == 1 { split($2, v, "."); print v[1] }' <<<"$XCODE_VERSION")"
  [ "$XCODE_MAJOR" -ge 26 ] || fail "сборка под iOS 18, а для перехода на iOS 26 нужен Xcode 26 (сейчас $XCODE_MAJOR)"
  echo "Сборка под iOS 18 — перехожу на iOS 26 (docs/IOS26-BUILD.md)"
  # The switch line, and its comment block above (from the "Минимальная iOS" line to the switch).
  /usr/bin/python3 - "$XCCONFIG" "$IOS18_LINE" <<'PY'
import sys
path, marker = sys.argv[1], sys.argv[2]
lines = open(path).read().split("\n")
switch = next(i for i, l in enumerate(lines) if marker in l)
target = next(i for i in range(switch, -1, -1) if lines[i].startswith("IPHONEOS_DEPLOYMENT_TARGET ="))
start = target
while start > 0 and lines[start - 1].startswith("//"):
    start -= 1
lines[start:switch + 1] = ["// Минимальная iOS — 26.0.", lines[target]]
open(path, "w").write("\n".join(lines))
PY
  git commit --quiet -m "Build: iOS 26 minimum, the iOS 18 switch line is gone" -- "$XCCONFIG"
  git push --quiet "$REMOTE" "$BRANCH"
  echo "Переход закоммичен и запушен"
else
  echo "Уже под iOS 26"
fi

# 3. Айфон и соединение
# Away from home the iPhone is reached over Tailscale through RoamRun (github.com/mh-mobile/RoamRun): the bridge is raised first, then Xcode and devicectl see the iPhone as if it were on this Wi-Fi.
if [ -z "${SP_DIRECT:-}" ] && command -v roamrun >/dev/null 2>&1; then
  step "Проверяю мост RoamRun"
  ROAM_NAME="${SP_IPHONE:-$(roamrun devices --json 2>/dev/null | /usr/bin/python3 -c 'import json, sys; d = json.load(sys.stdin); print(d[0]["name"] if d else "")' 2>/dev/null || true)}"
  if [ -z "$ROAM_NAME" ]; then
    echo "в RoamRun нет айфона — ищу его как обычно"
  elif roamrun status "$ROAM_NAME" >/dev/null 2>&1; then
    echo "$ROAM_NAME: $(roamrun status "$ROAM_NAME" --json | /usr/bin/python3 -c 'import json, sys; print(json.load(sys.stdin)[0]["status"])')"
  else
    echo "Поднимаю мост до $ROAM_NAME (айфон: разблокирован, в любом Wi-Fi с интернетом, Tailscale включён)"
    roamrun up "$ROAM_NAME" -d >/dev/null 2>&1 || true
    roamrun status "$ROAM_NAME" --wait 60 >/dev/null 2>&1 \
      || fail "мост до $ROAM_NAME не поднялся — айфон разблокировать, подключить к Wi-Fi, включить Tailscale; подробности: roamrun doctor"
    echo "Мост готов"
  fi
fi

step "Ищу айфон"
DEVICES_JSON="$(mktemp)"
find_iphone() {
  xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null 2>&1 || return 1
  /usr/bin/python3 - "$DEVICES_JSON" "${SP_IPHONE:-}" <<'PY'
import json, sys
wanted = sys.argv[2]
for d in json.load(open(sys.argv[1]))["result"]["devices"]:
    hw, conn = d["hardwareProperties"], d["connectionProperties"]
    if hw.get("deviceType") != "iPhone" or conn.get("pairingState") != "paired":
        continue
    if wanted and d["deviceProperties"].get("name") != wanted:
        continue
    print(d["identifier"], hw["udid"], conn.get("transportType", "?"), d["deviceProperties"].get("name"), sep="\t")
    break
PY
}
reachable() { xcrun devicectl device info details --device "$1" >/dev/null 2>&1; }

IPHONE="$(find_iphone || true)"
[ -n "$IPHONE" ] || fail "нет сопряжённого айфона (подключить проводом один раз и нажать «Доверять»)"
IFS=$'\t' read -r DEVICE_ID DEVICE_UDID TRANSPORT DEVICE_NAME <<<"$IPHONE"
echo "$DEVICE_NAME ($([ "$TRANSPORT" = "wired" ] && echo "провод" || echo "Wi-Fi"))"

if ! reachable "$DEVICE_ID"; then
  echo "Айфон не отвечает — открываю Xcode, чтобы он поднял соединение"
  echo "(айфон должен быть разблокирован и в той же Wi-Fi-сети, что и Mac)"
  open -g -a Xcode
  for ((i = 1; i <= WAKE_TRIES; i++)); do
    sleep "$WAKE_PAUSE"
    reachable "$DEVICE_ID" && break
    [ "$i" -eq "$WAKE_TRIES" ] && fail "айфон $DEVICE_NAME так и не ответил — разблокировать, проверить Wi-Fi или подключить проводом"
    echo "…жду ($((i * WAKE_PAUSE)) с)"
  done
fi
echo "Соединение есть"

# 4. Сборка и установка
# Xcode reuses a cached profile while it is valid, so a reinstall keeps the old expiry. Without this app's cached
# profiles the build fetches new ones: the signature counts its 7 days from this install.
step "Обновляю профили подписи (7 дней с этой установки)"
BUNDLE_ID="$(awk -F' *= *' '$1 == "SP_BUNDLE_ID" { print $2 }' "$XCCONFIG")"
[ -n "$BUNDLE_ID" ] || fail "нет SP_BUNDLE_ID в $XCCONFIG"
for profile in "$PROFILES"/*.mobileprovision; do
  [ -e "$profile" ] || continue
  APP_ID="$(security cms -D -i "$profile" 2>/dev/null | plutil -extract Entitlements.application-identifier raw - 2>/dev/null || true)"
  case "${APP_ID#*.}" in
    "$BUNDLE_ID" | "$BUNDLE_ID".*) rm -f "$profile"; echo "старый профиль ${APP_ID#*.} убран" ;;
  esac
done

step "Собираю Release для $DEVICE_NAME"
xcodebuild -project SuperPooper.xcodeproj -scheme SuperPooper -configuration Release \
  -destination "id=$DEVICE_UDID" -allowProvisioningUpdates \
  -derivedDataPath "$DERIVED" -clonedSourcePackagesDirPath ./.build/SourcePackages \
  build -quiet
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$APP/Info.plist")
EXPIRES="$(security cms -D -i "$APP/embedded.mobileprovision" | plutil -extract ExpirationDate raw -)"
echo "Собрано, минимальная iOS $MIN_OS, подпись до $EXPIRES"

step "Ставлю на айфон"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP" >/dev/null
echo "✔ Установлено на $DEVICE_NAME ($(git log --oneline -1))"
notify "Установлено на $DEVICE_NAME"
