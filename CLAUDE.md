# SuperPooper — карта для Claude Code

iPhone-приложение (SwiftUI, iOS 26) над Obsidian TaskNotes, Apple Calendar и Reminders. Своей базы задач нет. Подробности — **`docs/HANDBOOK.md`** (карта конфигов, логика дня, формат заметки, частые поломки). Решения — `DECISIONS.md`, история и план — `PROGRESS.md`.

## Команды (всё внутри проекта, DerivedData — в `.build/`)
```bash
scripts/xcb.sh build                                    # сборка под симулятор "SuperPooper Test"
scripts/xcb.sh test -only-testing:SuperPooperTests      # unit-тесты
scripts/sim.sh load-vault && scripts/xcb.sh test -only-testing:SuperPooperUITests   # UI-тесты
scripts/sim.sh install && scripts/sim.sh launch -SPVaultPath TestVault -SPSeedDemo -SPSkipOnboarding
scripts/make-ipa.sh                                     # .ipa для AltStore
```
`xcb.sh` = `xcodebuild … -derivedDataPath ./.build/DerivedData -clonedSourcePackagesDirPath ./.build/SourcePackages`. Симулятор задаётся `SP_SIMULATOR` (по умолчанию «SuperPooper Test»).

## Правила проекта
- **Архитектура — главное требование.** Экраны → `AppModel` → `Domain` (чистые функции) → репозитории → источники. Экран не читает файлы и не зовёт EventKit.
- **Конфиги вместо хардкода.** Числа, цвета, шрифты — `Resources/Config/tokens.json`; иконки — `icons.json`; действия и меню — `actions.json`; раскладка Today — `layouts/today.layout.json`; сортировка — `sort.json`; поля TaskNotes — `field-mapping.json`; флаги — `feature-flags.json`; правила — `rules.json`; умолчания настроек — `defaults.json`; тексты — `Localizable.xcstrings`. Особые случаи через `if` по имени/id запрещены.
- Один файл — одна ответственность, ~300 строк максимум. Без копипаста. Логика покрыта unit-тестами.
- Интерфейс и комментарии в коде — по-английски; документация — по-русски.
- Время — только из `Clock`, не `Date()` в логике. Swift 5 language mode.
- Новые файлы просто кладутся в нужную папку (синхронизируемые группы Xcode) — `project.pbxproj` трогать не нужно.
- **Код плагина TaskNotes не менять.** Формат заметок — как пишет TaskNotes (см. HANDBOOK §5).
- Git только локальный. «Релизь» = коммит с описанием всего нового с прошлого коммита + тег-релиз с буллет-списком нового с прошлого релиза. Коммиты и релизы — только по команде пользователя.
- После изменений — собрать и поставить в симулятор. В симулятор заходить, только чтобы найти баг, о котором сказал пользователь.
