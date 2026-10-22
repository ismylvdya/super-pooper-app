#!/bin/bash
# Собирает .ipa для AltStore: Release-сборка для устройства → Payload/SuperPooper.app → zip → .ipa.
# Нужна подпись своим Personal Team (выберите команду в Xcode один раз, см. TRANSFER.md).
# Результат: .build/SuperPooper.ipa
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild build \
  -project SuperPooper.xcodeproj -scheme SuperPooper -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ./.build/DerivedData \
  -clonedSourcePackagesDirPath ./.build/SourcePackages \
  -allowProvisioningUpdates -quiet
rm -rf .build/ipa && mkdir -p .build/ipa/Payload
cp -R .build/DerivedData/Build/Products/Release-iphoneos/SuperPooper.app .build/ipa/Payload/
(cd .build/ipa && /usr/bin/zip -qry ../SuperPooper.ipa Payload)
echo "Готово: .build/SuperPooper.ipa"
