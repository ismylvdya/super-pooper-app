#!/bin/bash
# Эталонные снимки основных экранов (UITests/ScreenSnapshotUITests) для проверки рефакторинга.
# scripts/snapshots.sh <папка> [quick]
#   полный прогон: «SuperPooper Mini» (iPhone 13 mini) и «SuperPooper Max» (iPhone 16 Pro Max),
#   светлая и тёмная тема, обычный и крупный шрифт — по папке на сочетание;
#   quick: только Mini, светлая тема, обычный шрифт.
# Сравнение двух прогонов: swift scripts/compare-snapshots.swift <эталон> <новый> [<папка разниц>]
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p "$1"
OUT="$(cd "$1" && pwd)"
MODE="${2:-full}"

udid() { xcrun simctl list devices available -j | /usr/bin/python3 -c "import json,sys; name=sys.argv[1]; print(next((d['udid'] for r in json.load(sys.stdin)['devices'].values() for d in r if d['name']==name), ''))" "$1"; }
[ -n "$(udid "SuperPooper Max")" ] || xcrun simctl create "SuperPooper Max" "iPhone 16 Pro Max" >/dev/null

if [ "$MODE" = quick ]; then
  DEVICES=("SuperPooper Mini"); APPEARANCES=(light); SIZES=(large)
else
  DEVICES=("SuperPooper Mini" "SuperPooper Max"); APPEARANCES=(light dark); SIZES=(large extra-extra-extra-large)
fi

SP_SIMULATOR="${DEVICES[0]}" scripts/xcb.sh build-for-testing -quiet >/dev/null

for DEVICE in "${DEVICES[@]}"; do
  ID="$(udid "$DEVICE")"
  WAS_BOOTED="$(xcrun simctl list devices | grep -q "$ID) (Booted)" && echo yes || echo no)"
  SP_SIMULATOR="$DEVICE" scripts/sim.sh boot
  xcrun simctl status_bar "$ID" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularMode notSupported
  SP_SIMULATOR="$DEVICE" scripts/sim.sh install
  SP_SIMULATOR="$DEVICE" scripts/sim.sh grant >/dev/null 2>&1
  for APPEARANCE in "${APPEARANCES[@]}"; do
    for SIZE in "${SIZES[@]}"; do
      NAME="$(echo "$DEVICE" | sed 's/SuperPooper //')-$APPEARANCE-$SIZE"
      echo "== $NAME"
      xcrun simctl ui "$ID" appearance "$APPEARANCE"
      xcrun simctl ui "$ID" content_size "$SIZE"
      SP_SIMULATOR="$DEVICE" scripts/sim.sh load-vault >/dev/null
      TEST_RUNNER_SP_SNAPSHOT_DIR="$OUT/$NAME" SP_SIMULATOR="$DEVICE" scripts/xcb.sh test-without-building -quiet \
        -only-testing:SuperPooperUITests/ScreenSnapshotUITests 2>&1 | grep -E "error:|failed|passed" | grep -v "^Test Case.*passed" || true
    done
  done
  xcrun simctl ui "$ID" appearance light
  xcrun simctl ui "$ID" content_size large
  xcrun simctl status_bar "$ID" clear
  [ "$WAS_BOOTED" = yes ] || xcrun simctl shutdown "$ID"
done
find "$OUT" -name "*.png" | wc -l | xargs echo "снимков:"
