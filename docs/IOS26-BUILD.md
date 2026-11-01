# Переход на iOS 26 (инструкция для агента с Xcode 26)

Этот Mac собирает приложение Xcode 16.4 (iOS 18 SDK): минимальная iOS тогда 18.0, а на iOS 26 приложение идёт в «режиме совместимости» (без Liquid Glass). Настоящая сборка под iOS 26 — на Mac с **Xcode 26** и симулятором **iOS 26**. Проект к ней готов: переход — одна строка.

## Коротко

- **Переход — удалить одну строку** в `Config/Shared.xcconfig`:
  ```
  IPHONEOS_DEPLOYMENT_TARGET[sdk=iphone*18*] = 18.0
  ```
  Больше ничего менять не нужно. Строка срабатывает только с SDK iOS 18 (Xcode 16, устройство и симулятор): с ней приложение и `.ipa` собираются с минимальной iOS 18.0. В Xcode 26 она и так не действует — там минимальная iOS уже 26.0 и код iOS 26 компилируется. Удаление закрывает сборку под iOS 18: Xcode 16 после него проект под iOS 18 не соберёт.
- **Код iOS 26 — в одном месте:** `DesignSystem/Platform/`. Всё, что выглядит по-разному на iOS 18 и iOS 26 (стекло, материалы, карточка баннера, затухание краёв под системными панелями), идёт через `.systemLook(_:)`; API iOS 26 есть только в `LiquidGlassLook.swift` под `#if compiler(>=6.2)`.
- **`if #available(iOS 26.0, *)` в коде один** — строка в `SystemLookModifier` (`DesignSystem/Platform/SystemLook.swift`, над ней комментарий «The switch line»). При минимальной 26.0 предупреждения «unnecessary check» он не даёт: Swift предупреждает о лишней проверке только внутри объявления с `@available`, а проверку, которую закрывает минимальная версия, не трогает (проверено на Swift 6.1 этого Mac). **Если Xcode 26 всё же предупредит** — единственная правка: строку
  ```swift
  if #available(iOS 26.0, *) { content.modifier(LiquidGlassLook(look: look)) } else { content.modifier(ClassicLook(look: look)) }
  ```
  заменить на
  ```swift
  content.modifier(LiquidGlassLook(look: look))
  ```
- **Важно:** `LiquidGlassLook.swift` на этом Mac не компилировался ни разу (Xcode 16 его пропускает). В нём только документированный API iOS 26: `glassEffect(_:in:)`, `Glass.regular`, `.interactive()`, `scrollEdgeEffectStyle(_:for:)`, плюс обычный `hidden()`. Если первая сборка в Xcode 26 найдёт в нём ошибку — чинить там же, не вынося API iOS 26 за пределы `DesignSystem/Platform/`.
- Уборка после перехода (не обязательна, отдельным коммитом): вид iOS 18 больше не нужен — `ClassicLook.swift` и ветки `#else` / `#if compiler(>=6.2)` в `SystemLook.swift` и `LiquidGlassLook.swift` можно убрать, оставив в `SystemLookModifier` одну строку из примера выше.

## Что где лежит

| Файл | Что в нём |
|---|---|
| `DesignSystem/Platform/SystemLook.swift` | виды, которые решает система: капсула кнопок панели и таб-бара боком (`barCapsule`), счётчик «+N more» над пулом (`floatingCapsule`), карточка баннера (`bannerCard`), прокрутка, края которой лежат под системной панелью (`scrollUnderBars`), ручное затухание у такого края (`fadeUnderBar`); единственный выбор между iOS 18 и iOS 26 |
| `DesignSystem/Platform/ClassicLook.swift` | вид iOS 18: материал `.bar`, `.regularMaterial`, карточка `bannerBackground` с тенью, ручное затухание краёв |
| `DesignSystem/Platform/LiquidGlassLook.swift` | вид iOS 26: `glassEffect` (у кнопок — `.interactive()`), стекло вместо карточки с тенью, `scrollEdgeEffectStyle(.soft, for:)` под панелями, ручное затухание там скрыто |
| `DesignSystem/Platform/SystemBarTokens.swift` | метрики системных панелей, которые приложение копирует для своих панелей боком; значения — `tokens.json` → `systemBar` |
| `DesignSystem/Platform/TabIconImage.swift` | глиф вкладки Lists, подогнанный под системные символы вкладок (своего SF-символа пока нет, см. «Известное») |
| `DesignSystem/Widgets/WidgetRendering.swift` | плашки виджетов в одном цвете (тонированный экран «Домой», на iOS 26 ещё прозрачный); работает и на iOS 18 |
| `DesignSystem/Components/EdgeFade.swift` | `.edgeFades(…barEdges:)`: какие края прокрутки лежат под системной панелью, решает экран (Today: низ блока у таб-бара, только стоя) |

## Шаги

1. Проверить окружение:
   ```bash
   xcodebuild -version                       # Xcode 26.x
   xcrun --sdk iphoneos --show-sdk-version   # 26.x
   xcrun simctl list runtimes | grep "iOS 26"
   ```
2. Взять актуальный `main`, работать в своей ветке (например `ios26`).
3. Симулятор для скриптов — «🌭 iPhone 13 mini» (его ждут `scripts/xcb.sh` и `scripts/sim.sh`; другой — через `SP_SIMULATOR`). Если его нет, создать ровно один:
   ```bash
   xcrun simctl create "🌭 iPhone 13 mini" "iPhone 13 mini" "$(xcrun simctl list runtimes | grep -o 'com.apple.CoreSimulator.SimRuntime.iOS-26[-0-9]*' | tail -1)"
   ```
4. Удалить строку `IPHONEOS_DEPLOYMENT_TARGET[sdk=iphone*18*] = 18.0` в `Config/Shared.xcconfig` (и строку комментария над ней про переход).
5. Собрать и прогнать тесты:
   ```bash
   scripts/xcb.sh build
   scripts/xcb.sh test -only-testing:SuperPooperTests
   scripts/sim.sh load-vault && scripts/xcb.sh test -only-testing:SuperPooperUITests
   scripts/check-vault-after-ui-tests.sh
   ```
   Сборка — без предупреждений (на Xcode 16 их ноль). Упавший тест — блокер. Новые ошибки или предупреждения Swift 6.2 и SDK 26 (устаревшие API, проверки конкурентности) — чинить по месту, не меняя поведения; проект в Swift 5 language mode, его не переключать.
6. Пройти экраны (список ниже):
   ```bash
   scripts/sim.sh install && scripts/sim.sh launch -SPVaultPath TestVault -SPSeedDemo -SPSkipOnboarding
   ```
   Снимки `ScreenSnapshotUITests` на iOS 26 — новый эталон: со снимками iOS 18 они не сравниваются.
7. Собрать `.ipa` (скрипт сам обновит `dist/altstore-source.json`):
   ```bash
   scripts/make-ipa.sh
   ```
8. Проверить, что сборка именно под iOS 26:
   ```bash
   unzip -p dist/SuperPooperApp.ipa Payload/SuperPooperApp.app/Info.plist | plutil -extract MinimumOSVersion raw -   # 26.0
   unzip -p dist/SuperPooperApp.ipa Payload/SuperPooperApp.app/Info.plist | plutil -extract DTPlatformVersion raw -  # 26.x
   grep minOSVersion dist/altstore-source.json                                                                   # "26.0"
   ```
9. Закоммитить правки и `dist/` по правилам проекта: коммит и релиз — только по команде пользователя.

## Что проверить на iOS 26, экран за экраном

1. **Today стоя.**
   - Верхняя панель: слева This week и значок проблем, справа New task и Search — системные стеклянные группы кнопок. Название дня со стрелками — посередине; стрелки листают дни, тап по названию возвращает сегодня. Если вокруг названия дня появилась стеклянная капсула и она лишняя — это решение владельца (снимается `sharedBackgroundVisibility(.hidden)` у `ToolbarItem(placement: .principal)` в `TodayScreen`, только под `#if compiler(>=6.2)`).
   - Таб-бар: плавающий, стеклянный, четыре вкладки; глиф Lists ростом с соседние символы.
   - Края: низ пула и таймлайна под таб-баром гасит системный мягкий край, ручного затухания там нет — затухание одно, не двойное. Верх пула и таймлайна (под панелью с отступом и под полосой all-day) и низ пула над таймлайном (раскладка Stacked) — ручное затухание, как на iOS 18. Если под таб-баром затухания нет совсем (система не узнала прокрутку) — в `TodayScreen.content` у `TodayBlock` убрать `.bottom` из `barEdges`: вернётся ручное. Если двойным оказался верхний край — добавить туда `.top`.
   - Счётчик «+N more» (Settings → Today screen → Stacked, пул сверху) — стеклянная капсула.
2. **Баннер** (потянуть Today вниз — «Synced…»): стеклянная карточка без тени; текст читается на светлом и тёмном фоне; смахивание вверх убирает, тап раскрывает.
3. **Today боком** (оба поворота): таб-бар — стеклянная колонка у физического низа, вкладки в том же порядке под теми же пальцами; кнопки панели — в стеклянных пузырях вдоль физического верха, такого же размера и на таком же расстоянии от краёв, как системные стоя. Подпись вкладки — 10 pt и не растёт с размером текста, как у системного таб-бара.
4. **Другие вкладки и страницы** (Habits, Lists, Settings, страница задачи, новая задача, This week): большие заголовки свои (`PageScaffold`), панель — inline; под панелью и таб-баром — системный край.
5. **Виджеты** — добавить Today (Large) и привычку (Small) на экран «Домой», Clock — на экран блокировки:
   - полный цвет — как на iOS 18; поля системные (виджеты их не отключают);
   - Tinted (долгое нажатие на экран «Домой» → Настроить → Тонированный): плашки полупрозрачные, заголовки на них читаются и не сливаются с плашкой; полоска события, точка события на весь день, линия «сейчас» и весь виджет привычки — в цвете акцента;
   - Clear (прозрачный): то же поверх стекла;
   - галерея в Debug (Settings → Debug → Widgets) рисует вью виджетов приложением с полями iPhone; Tinted и Clear в ней не видны — только на экране «Домой».
6. **Крупный текст** (Settings → Accessibility → Larger Text на максимум): Today, баннер и таб-бар боком не ломаются; подпись вкладки боком остаётся 10 pt.

Отказ от Liquid Glass (`UIDesignRequiresCompatibility = YES` в `Config/App-Info.plist`) — только по решению владельца.

## Если метрика не та — какой токен править

Код не трогать: всё, что приложение копирует с системных панелей, — `tokens.json` → `systemBar`.

| Что не так | Токен |
|---|---|
| Таб-бар боком шире или уже системного | `systemBar.metric.landscapeTabBarWidth` (60) |
| Вкладки внутри таб-бара боком теснее или свободнее | `systemBar.metric.tabBarInner` (4) |
| Таб-бар боком дальше или ближе к краям экрана, чем системный стоя | `systemBar.metric.landscapeBarInset` (20) |
| Символ вкладки боком, подпись, промежуток между ними | `systemBar.font.tabIcon`, `systemBar.font.tabLabel` (10, `"fixed": true`), `systemBar.metric.tabIconLabelGap` (4) |
| Кнопки в пузырях боком не того размера, промежуток между ними | `systemBar.metric.barButton` (42), `systemBar.metric.barButtonGap` (13) |
| Пузыри кнопок боком не на том расстоянии от сторон экрана | `systemBar.metric.barSideInset` (16) |
| Глиф Lists в системном таб-баре выше или ниже соседних символов | `systemBar.font.systemTabIcon` (по нему глиф подгоняется под самый высокий соседний символ) |
| Плашки виджетов в Tinted и Clear слишком бледные или плотные | `opacity.accentedPlate` (0.2) |
| Поля вью виджета в галерее Debug | `spacing.widgetMargin` (16; в самих виджетах поля системные) |
| Скругление карточки баннера | `radius.banner` (стекло iOS 26 берёт только его; цвет и тень карточки — только iOS 18) |
| Ручное затухание внутренних краёв | `size.fadeHeight`, `opacity.fadeTop`, `opacity.fadeMiddle`, `ratio.fadeMiddleStop` |

## Известное

- **Глиф вкладки Lists — картинка, а не SF-символ** (`TabIconImage` перерисовывает `TabLists.svg` под размер системных символов). Свой символ — задача владельца: в SVG линии с толщиной, а символу нужны залитые контуры в трёх насыщенностях; и один символ не повторит два нынешних правила размера (стоя — ростом с самый высокий соседний символ, боком — шириной с самый широкий). Когда символ появится: положить `.symbolset` в ассеты под тем же именем и убрать `TabIconImage`.
- **`.ipa` и AltStore.** `scripts/make-ipa.sh` минимальную iOS не трогает — её решает `Config/Shared.xcconfig` (до перехода в Xcode 16 — 18.0, в Xcode 26 — 26.0). `scripts/update-altstore-source.sh` берёт `minOSVersion` из `MinimumOSVersion` собранного приложения, поэтому источник AltStore всегда совпадает со сборкой.
