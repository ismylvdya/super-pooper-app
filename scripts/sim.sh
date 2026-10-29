#!/bin/bash
# Работа с собственным симулятором "🌭 iPhone 13 mini".
# scripts/sim.sh boot | install | load-vault | grant | launch [аргументы] | screenshot <файл> | seed
set -euo pipefail
cd "$(dirname "$0")/.."
SIMULATOR="${SP_SIMULATOR:-🌭 iPhone 13 mini}"
UDID="$(xcrun simctl list devices available -j | /usr/bin/python3 -c "import json,sys; name=sys.argv[1]; print(next((d['udid'] for r in json.load(sys.stdin)['devices'].values() for d in r if d['name']==name), ''))" "$SIMULATOR")"
[ -n "$UDID" ] || { echo "Симулятор '$SIMULATOR' не найден" >&2; exit 1; }
BUNDLE_ID="$(grep -E '^SP_BUNDLE_ID' Config/Shared.xcconfig | sed 's/.*= *//')"
APP=".build/DerivedData/Build/Products/Debug-iphonesimulator/SuperPooperApp.app"

case "${1:-}" in
  boot) xcrun simctl boot "$UDID" 2>/dev/null || true; xcrun simctl bootstatus "$UDID" -b >/dev/null ;;
  install) xcrun simctl install "$UDID" "$APP" ;;
  grant)
    xcrun simctl privacy "$UDID" grant calendar "$BUNDLE_ID" || true
    xcrun simctl privacy "$UDID" grant reminders "$BUNDLE_ID" || true ;;
  load-vault)
    DATA="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
    scripts/render-test-vault.sh "$DATA/Documents/TestVault" "${2:-}" ;;
  launch) shift; xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE_ID" "$@" ;;
  screenshot) xcrun simctl io "$UDID" screenshot "$2" >/dev/null && echo "$2" ;;
  udid) echo "$UDID" ;;
  *) echo "usage: $0 boot|install|grant|load-vault [date]|launch [args]|screenshot <file>|udid" >&2; exit 1 ;;
esac
