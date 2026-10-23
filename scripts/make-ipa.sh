#!/bin/bash
# Собирает .ipa для AltStore/SideStore без Apple ID: Release-сборка для устройства, ad-hoc подпись
# с entitlements (App Group), Payload/SuperPooper.app → zip → dist/SuperPooper.ipa.
# AltStore при установке сам переподписывает приложение и виджет Apple ID пользователя.
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_ID="$(grep -E '^SP_BUNDLE_ID' Config/Shared.xcconfig | sed 's/.*= *//')"
GROUP="group.$BUNDLE_ID"
EXTRA=()
# Если стоит Xcode со старым SDK (< iOS 26), собираем с минимальной iOS 18.0 — такой .ipa ставится и на iOS 26.
SDK_MAJOR="$(xcrun --sdk iphoneos --show-sdk-version | cut -d. -f1)"
if [ "$SDK_MAJOR" -lt 26 ]; then EXTRA+=("IPHONEOS_DEPLOYMENT_TARGET=18.0"); fi

xcodebuild build -quiet \
  -project SuperPooper.xcodeproj -scheme SuperPooper -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ./.build/DerivedData-device \
  -clonedSourcePackagesDirPath ./.build/SourcePackages \
  CODE_SIGNING_ALLOWED=NO CLANG_ENABLE_CODE_COVERAGE=NO \
  DEPLOYMENT_POSTPROCESSING=YES STRIP_INSTALLED_PRODUCT=YES COPY_PHASE_STRIP=YES \
  OTHER_SWIFT_FLAGS="-file-prefix-map $PWD=." \
  ${EXTRA[@]+"${EXTRA[@]}"}

APP=.build/DerivedData-device/Build/Products/Release-iphoneos/SuperPooper.app
ENTITLEMENTS=.build/ipa-entitlements.plist
sed "s/\$(SP_APP_GROUP)/$GROUP/" Config/SuperPooper.entitlements > "$ENTITLEMENTS"
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP/PlugIns/SuperPooperWidgets.appex"
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP"

rm -rf .build/ipa && mkdir -p .build/ipa/Payload dist
cp -R "$APP" .build/ipa/Payload/
rm -f dist/SuperPooper.ipa
(cd .build/ipa && /usr/bin/zip -qry ../../dist/SuperPooper.ipa Payload)
# Никаких следов машины сборки и чужого Apple ID: подпись ad-hoc, без Team ID и профилей, без путей.
for BIN in "$APP/SuperPooper" "$APP/PlugIns/SuperPooperWidgets.appex/SuperPooperWidgets"; do
  if grep -a -q "$HOME" "$BIN"; then echo "Ошибка: в $BIN есть путь машины сборки" >&2; exit 1; fi
  # Без пайпа: с pipefail `grep -q` обрывает вывод codesign и проверка ложно падает.
  [[ "$(codesign -dv "$BIN" 2>&1)" == *"TeamIdentifier=not set"* ]] || { echo "Ошибка: в $BIN есть Team ID" >&2; exit 1; }
done
[ -z "$(find "$APP" -name '*.mobileprovision')" ] || { echo "Ошибка: в .ipa есть provisioning profile" >&2; exit 1; }

scripts/update-altstore-source.sh
echo "Готово: dist/SuperPooper.ipa ($(du -h dist/SuperPooper.ipa | cut -f1))"
