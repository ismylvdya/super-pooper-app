#!/bin/bash
# Обёртка над xcodebuild: DerivedData и кэш SPM — внутри проекта (.build/),
# сборка под собственный симулятор "🌭 iPhone 13 mini".
# Использование: scripts/xcb.sh build|test|build-for-testing [доп. аргументы xcodebuild]
set -euo pipefail
cd "$(dirname "$0")/.."

ACTION="${1:-build}"
shift || true
SIMULATOR="${SP_SIMULATOR:-🌭 iPhone 13 mini}"
SIMULATOR_ID="$(xcrun simctl list devices available -j | /usr/bin/python3 -c "import json,sys; name=sys.argv[1]; print(next((d['udid'] for r in json.load(sys.stdin)['devices'].values() for d in r if d['name']==name), ''))" "$SIMULATOR")"
if [ -z "$SIMULATOR_ID" ]; then
  echo "Симулятор '$SIMULATOR' не найден. Создайте его: xcrun simctl create \"$SIMULATOR\" \"iPhone 13 mini\"" >&2
  exit 1
fi


exec xcodebuild "$ACTION" \
  -project SuperPooper.xcodeproj \
  -scheme SuperPooper \
  -configuration "${SP_CONFIGURATION:-Debug}" \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath ./.build/DerivedData \
  -clonedSourcePackagesDirPath ./.build/SourcePackages \
  -resultBundlePath "./.build/Results/$ACTION-$(date +%Y%m%d-%H%M%S).xcresult" \
  "$@"
