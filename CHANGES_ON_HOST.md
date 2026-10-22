# Изменения на машине сборки вне папки проекта

| Что | Где | Как откатить |
|---|---|---|
| Симулятор «SuperPooper Test» (iPhone 16 Pro, iOS 18.6), UDID `2FBD90F8-CD4A-4263-8F32-88DDE7718872` | `~/Library/Developer/CoreSimulator/Devices/2FBD90F8-…` | `xcrun simctl delete 2FBD90F8-CD4A-4263-8F32-88DDE7718872` |
| Логи Xcode/xcodebuild и временные result bundle | `~/Library/Logs`, `/var/folders/…` (системные временные папки) | не требуется, система чистит сама |

- Homebrew-пакеты не устанавливались (XcodeGen не нужен: проект написан вручную).
- Глобальный git-конфиг, `~/.zshrc`, `~/.claude` не менялись. Git-авторство задано только в локальном конфиге репозитория.
- Исходники TaskNotes и пакет `@tasknotes/model` скачаны только для чтения в `.build/` внутри проекта (удаляется вместе с `.build/`).
