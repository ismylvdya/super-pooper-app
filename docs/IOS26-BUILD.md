# Сборка .ipa под iOS 26 (инструкция для агента с Xcode 26)

Этот Mac собирает приложение Xcode 16.4 (iOS 18 SDK): `.ipa` из `scripts/make-ipa.sh` тогда получается с минимальной iOS 18.0 и в «режиме совместимости» на iOS 26 (без Liquid Glass). Чтобы собрать настоящую сборку под iOS 26, нужен Mac с **Xcode 26** и симулятором **iOS 26**. Код менять не нужно: проект к этому готов.

## Что уже сделано в проекте

- `Config/Shared.xcconfig`: `IPHONEOS_DEPLOYMENT_TARGET = 26.0`. Строка `IPHONEOS_DEPLOYMENT_TARGET[sdk=iphonesimulator18*] = 18.0` срабатывает только со старым SDK; в Xcode 26 она ничего не делает.
- `scripts/make-ipa.sh` смотрит версию SDK: при SDK < 26 добавляет `IPHONEOS_DEPLOYMENT_TARGET=18.0`, при SDK 26 собирает как есть — с минимальной iOS 26.0.
- `scripts/update-altstore-source.sh` берёт `minOSVersion` из `Info.plist` собранного приложения (`MinimumOSVersion`), а не пишет 18.0.

## Шаги

1. Проверить окружение:
   ```bash
   xcodebuild -version                 # Xcode 26.x
   xcrun --sdk iphoneos --show-sdk-version   # 26.x
   xcrun simctl list runtimes | grep "iOS 26"
   ```
2. Взять актуальный `main`, работать в своей ветке (например `ios26-build`).
3. Завести симулятор для скриптов (имя важно — его ждут `scripts/xcb.sh` и `scripts/sim.sh`):
   ```bash
   xcrun simctl create "SuperPooper Test" "iPhone 17" "$(xcrun simctl list runtimes | grep -o 'com.apple.CoreSimulator.SimRuntime.iOS-26[-0-9]*' | tail -1)"
   ```
4. Собрать и прогнать тесты:
   ```bash
   scripts/xcb.sh build
   scripts/xcb.sh test -only-testing:SuperPooperTests
   scripts/sim.sh load-vault && scripts/xcb.sh test -only-testing:SuperPooperUITests
   ```
   Упавший тест — блокер. Если Xcode 26 выдал ошибки или предупреждения компиляции (новые проверки Swift 6.2, устаревшие API) — исправить по месту, не меняя поведения; проект в Swift 5 language mode, его не переключать.
5. Посмотреть на экраны в симуляторе (Liquid Glass включается сам, когда приложение собрано с iOS 26 SDK):
   ```bash
   scripts/sim.sh install && scripts/sim.sh launch -SPVaultPath TestVault -SPSeedDemo -SPSkipOnboarding
   ```
   Особое внимание: верхняя панель Today (стрелки дня и кнопки по краям — ширина середины считается от `size.todayBarSideWidth` в `tokens.json`), таб-бар, landscape. Если панель стала другой ширины — поправить токен, а не код. Отказ от Liquid Glass (`UIDesignRequiresCompatibility = YES` в `Config/App-Info.plist`) — только по решению пользователя.
6. Собрать `.ipa`:
   ```bash
   scripts/make-ipa.sh
   ```
   Скрипт сам обновит `dist/altstore-source.json`.
7. Проверить, что сборка именно под iOS 26:
   ```bash
   unzip -p dist/SuperPooper.ipa Payload/SuperPooper.app/Info.plist | plutil -extract MinimumOSVersion raw -   # 26.0
   unzip -p dist/SuperPooper.ipa Payload/SuperPooper.app/Info.plist | plutil -extract DTPlatformVersion raw -  # 26.x
   grep minOSVersion dist/altstore-source.json                                                             # "26.0"
   ```
8. Закоммитить `dist/` и правки (если были) по правилам проекта: коммит и релиз — только по команде пользователя.
