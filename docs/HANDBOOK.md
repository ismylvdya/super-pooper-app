# SuperPooper — справочник

Документ для человека и для нового агента (Claude Code). Сначала — что это и где что лежит, потом — как устроена логика, потом — рецепты и частые поломки.

## 1. Что это и зачем

SuperPooper — iPhone-приложение-оболочка над тремя системами. Своей базы задач у него **нет**:

| Что | Где живёт | Что делает приложение |
|---|---|---|
| Задачи, привычки, периодические дела | `.md`-заметки TaskNotes в vault Obsidian (iCloud Drive) | читает, точечно правит frontmatter и текст; новых заметок не создаёт |
| Жёсткие события («якоря») | Apple Calendar, календари выбраны в настройках | только читает, показывает на таймлайне |
| «Вспомнить в X» | Apple Reminders, листы выбраны в настройках | только читает, шлёт своё уведомление |
| Inbox | отдельный лист Reminders | **не трогает** |
| Ручной порядок пула, Skip today | App Group, только на сегодня | потеря не страшна |
| Настройки, снимок для виджетов, бэкапы | App Group (JSON) | общие с виджетами; можно стереть |

Главный экран Today: сверху **пул** — дела дня без времени (просрочиться не могут), ниже **таймлайн** с линией «сейчас»: события, всё со временем и цепочки дел, привязанные к событиям. Без streak'ов, без почасового планирования.

## 2. Карта папок

| Папка | Что внутри | В каких таргетах |
|---|---|---|
| `App/` | точка входа, composition root (`AppContainer`), `RootView`, состояние приложения `State/` (`AppModel` + расширения по темам, `Router`, `BannerCenter`), делегат уведомлений и background refresh | приложение |
| `Features/` | экраны: `Today/`, `TaskPage/`, `Pickers/`, `MorningReview/`, `Settings/`, `Onboarding/`, `Archive/`, `Common/` | приложение |
| `DesignSystem/` | токены (`Tokens/`), общие компоненты (`Components/`: плашки, чипы, строка задачи, таймлайн, баннер), вью виджетов (`Widgets/`), превью (`Previews/`) | приложение + виджеты |
| `Domain/` | чистая логика без SwiftUI/EventKit: модели, день (`Day/`), RRULE (`Recurrence/`), план уведомлений | приложение + виджеты |
| `Data/` | vault (bookmark, iCloud, координированные файлы, бэкапы), frontmatter (чтение и точечная запись YAML), репозитории, EventKit, уведомления | приложение |
| `Core/` | загрузка конфигов (`Config/`), хранилище App Group (`Storage/`), часы, тексты, deep links (`Environment/`), App Intent выбора привычки (`Intents/`), источник данных виджетов (`Widgets/`) | приложение + виджеты |
| `Resources/` | конфиги `Config/*.json`, `Localizable.xcstrings` | приложение + виджеты |
| `AppResources/` | `Assets.xcassets` (иконка) | приложение |
| `Widgets/` | WidgetKit: Today (Large) и Habit grid (Small/Medium) | виджеты |
| `Debug/` | только DEBUG: демо-данные календаря, экран уведомлений, галерея виджетов, модель для превью | приложение |
| `Tests/` | unit-тесты (Swift Testing), `Support/TestVaultRenderer.swift` | тесты |
| `UITests/` | UI-тесты ключевых сценариев (XCTest) | UI-тесты |
| `Fixtures/TestVault/` | шаблоны тестового vault (38 заметок) | — |
| `Config/` | xcconfig (ID, версии), Info.plist, entitlements | — |
| `scripts/` | сборка, симулятор, рендер тестового vault, `.ipa` | — |

Проект — обычный `SuperPooper.xcodeproj` с **синхронизируемыми папками** (Xcode 16+): новый файл в папке сам попадает во все таргеты этой папки, `project.pbxproj` править не нужно.

Слои и направление вызовов: **экраны → состояние (`AppModel`) → домен (`Domain/`) → репозитории (`Data/Repositories`) → источники (файлы, EventKit, уведомления)**. Экран не читает файлы и не зовёт EventKit. Домен — чистые функции: данные и «сейчас» на входе, результат на выходе.

## 3. Карта конфигов: чтобы изменить X — правь Y

Все конфиги — `Resources/Config/`. Они проверяются при запуске: опечатка в ключе — экран с именем файла и путём к ключу, а не падение.

| Чтобы изменить… | Правь |
|---|---|
| Раскладку Today (пул сверху/слева, доли места, порядок блоков) | `layouts/today.layout.json`: `axis` (`vertical`/`horizontal`), `blocks` (`size`: `fit` или `fill` + `weight`), `spacing` (имя токена). Тот же файл — у виджета Today |
| Отступы, скругления, размеры, прозрачности, длительности, шрифты, цвета (светлые и тёмные) | `tokens.json`. Новый токен = ключ в JSON + `case` в `DesignSystem/Tokens/TokenKeys.swift` |
| Иконки SF Symbols вне действий | `icons.json` (+ `case` в `Core/Config/IconSet.swift` для нового) |
| Действия (название, иконка, вибрация, подтверждение) и состав меню/уведомлений | `actions.json` (`actions` и `menus`) |
| Порядок критериев сортировки пула | `sort.json` → `pool` (список; переставить строки = поменять приоритет) |
| Имена полей TaskNotes и значения статусов/приоритетов | `field-mapping.json` |
| Включить/выключить функцию | `feature-flags.json` |
| Пороги и правила: оценка по умолчанию, подписи оценок (`2 min`…`dohuya`), лимит уведомлений, горизонт, окно поиска событий, таймаут iCloud, число бэкапов, шаги виджетов | `rules.json` |
| Значения настроек по умолчанию (папка задач, тег, граница дня, час энергии, раскладка таймлайна…) | `defaults.json` |
| Тексты интерфейса, уведомлений, виджетов | `Resources/Localizable.xcstrings` (ключи вида `settings.day.boundary`) |
| Bundle ID / App Group / версию | `Config/Shared.xcconfig` (`SP_BUNDLE_ID`, `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) |

Пример из манифеста: «пул сверху, таймлайн снизу» → «пул слева, таймлайн справа» = заменить `"axis": "vertical"` на `"axis": "horizontal"` в `today.layout.json` (проверено, см. `PROGRESS.md`).

Пользовательские настройки хранятся в App Group (`settings.json`) и при чтении **накладываются на `defaults.json`**: новые поля из новой версии сразу получают значения по умолчанию.

## 4. Как устроен день

Код: `Domain/Day/DayBuilder.swift` и соседи. Всё считается заново от «сейчас» (раз в минуту на экране, на каждую запись в виджете).

### 4.1. Граница дня
`day.boundary` (по умолчанию 04:00): до неё ещё «вчера». `DayContext.today` — логическая дата. Время до границы относится к концу логического дня: привычка в 00:30 стоит в конце сегодняшнего таймлайна (`DayContext.moment`), задача с `due` на 01:00 следующей даты — сегодняшняя (`DayContext.logicalDay`).

### 4.2. Что попадает в день
- задачи `this_week` без `recurrence`;
- задачи, отмеченные `done` сегодня (`completed_date` = сегодня) — видны как сделанные до конца дня;
- повторяющиеся задачи, у которых по `recurrence` есть экземпляр сегодня (статус не важен), или уже отмеченные сегодня;
- не попадают: Skip today, `waiting`, `half_year`, `someday`, `archived`, сделанные раньше.

### 4.3. Пул и таймлайн
- **Таймлайн**: события выбранных календарей; задачи и привычки со временем (`due` с временем: у обычной задачи — на сегодня, у привычки — время дня); напоминания Reminders; задачи, связанные с событием через `previous_event`/`next_event`, **и их последователи по `previous_task`** (косвенно).
- **Пул**: всё остальное, включая задачи, связанные только друг с другом.
- **Цепочки** (`ChainLayout`): «до события» (`next_event`) — подряд от «сейчас»; «после события» (`previous_event`) — от конца события или от «сейчас», если оно закончилось. Невыполненные идут за курсором и сдвигаются вместе с «сейчас», сделанные складываются перед курсором. Длительность — `time_estimate` (пусто = 15 мин).
- **Отрисовка** (`DayTimelineView`): высота блока — по оценке, но не меньше строки текста; блок, не пересекающийся с предыдущим по времени, но наезжающий визуально, сдвигается ниже; реально пересекающиеся — рядом в колонках, как в Calendar.

Пример: сейчас 11:30, «Подготовить вопросы папе» (`next_event: Call with dad 19:00`) → 11:30–11:45; «Распечатать вопросы» (`previous_task: Подготовить…`) → 11:45–12:00, заблокирована; «Записать итоги разговора» (`previous_event: Call with dad`) → 20:00, заблокирована до конца звонка.

### 4.4. Блокировка (`BlockingEvaluator`)
- Задача заблокирована, пока не сделаны все `previous_task`: обычная — статус `done`/`archived`; повторяющаяся — сегодня отмечена или пропущена Skip today; повторяющаяся без экземпляра сегодня не блокирует.
- `previous_event` блокирует до окончания события.
- Ссылка на несуществующую задачу не блокирует (значок проблемы).
- Циклы разрываются (одна связь игнорируется), участникам — значок проблемы.
- Заблокированная задача приглушена, отметить её нельзя (тап объясняет, что держит), в пуле она всегда после своих предшественников.

### 4.5. Сортировка пула (`PoolSorter`, порядок — `sort.json`)
1. `habitsFirst` — привычки без времени первыми, в порядке их связей;
2. `dueToday` — `due` сегодня;
3. `highPriority`;
4. `nearestDueThisWeek` — ближайший `due` на этой неделе;
5. `energyBeforeEnergyHour` — `need_energy` до часа энергии выше, после — ниже;
6. `unpleasantFirst` — `pleasant: false` раньше;
7. `shortFirst` — короткая оценка раньше;
8. `olderFirst` — старше `date_created` раньше.

Поверх: задача никогда не выше своих `previous_task` (стабильная топологическая сортировка); сделанные сегодня — в конце.

**Ручной порядок** (утренний разбор): пока ничего не перетащено, порядок пересчитывается после каждой правки. После первого перетаскивания порядок фиксируется на сегодня (`day-state.json`); новые задачи встают после своего соседа по автосортировке; «Reset to auto» возвращает авто.

### 4.6. Автоперевод
При открытии и pull-to-refresh задачи `half_year`/`someday` без `recurrence` с `due` с сегодня по воскресенье получают `this_week` (перед этим — бэкап). Список статусов — `rules.json` → `day.autoPromoteFrom`. Статусы приложение никогда не понижает.

### 4.7. Привычки
- Привычка = задача с `recurrence` (RRULE TaskNotes). Время дня — из `due`, если там есть время.
- Тап = Done; долгое нажатие и уведомление — Partially, Twice, Skip today.
- Done → дата в `complete_instances`; Partially → в `complete_instances` и `partial_instances`; Twice → в `complete_instances` и `twice_instances`. Снятие — убирает из всех трёх.
- Skip today в заметку не пишется (только `day-state.json` до конца дня).
- `due` у привычек приложение **не двигает** (в отличие от TaskNotes, который при отметке переносит scheduled на следующий экземпляр) — см. DECISIONS.

### 4.8. RRULE (`Domain/Recurrence`)
Поддерживается то, что генерирует TaskNotes: `DTSTART` (дата или дата-время; «Z» — фиктивная, время локальное, как в TaskNotes), `FREQ=DAILY|WEEKLY|MONTHLY|YEARLY`, `INTERVAL`, `BYDAY` (в т.ч. `2MO`, `-1FR`), `BYMONTHDAY` (в т.ч. отрицательные), `BYMONTH`, `COUNT`, `UNTIL`, `WKST`. Без `DTSTART` точка отсчёта — дата из `due`, затем `date_created`. Незнакомое правило — задача видна каждый день со значком проблемы (как в TaskNotes). Поведение сверено с кодом TaskNotes 4.13.8 / rrule.js на 9000 случайных правил.

## 5. Формат заметки (для Claude-скилла)

- **Название задачи = имя файла** без `.md`. Поля `title` нет.
- Папка задач — `TaskNotes/Tasks` (настройка), признак задачи — тег `🔫делишка` в `tags`.

```yaml
---
tags:
  - 🔫делишка
status: this_week            # this_week | half_year | someday | waiting | done | archived
priority: high               # high | none
due: 2026-10-23T16:00        # YYYY-MM-DD или YYYY-MM-DDTHH:mm (локальное время)
time_estimate: 15            # минуты: 2 | 15 | 60 | 240; пусто = 15
previous_task:               # задачи, которые делаются ДО этой (блокировка)
  - uid: "[[Купить батарейки]]"
    reltype: FINISHTOSTART
previous_event: "8A1F…:A2B3…|Call with dad|2026-10-23T19:00:00+02:00"   # после события
next_event: "…"              # до события (тот же формат)
need_energy: true
pleasant: false
recurrence: DTSTART:20261001T090000Z;FREQ=DAILY     # есть поле → привычка/периодическое дело
complete_instances: [ ... ]  # дни с любой отметкой
partial_instances: [ ... ]   # дни с Partially (они же есть в complete_instances)
twice_instances: [ ... ]     # дни с Twice (они же есть в complete_instances)
completed_date: 2026-10-23   # ставится при отметке обычной задачи вместе с status: done
date_created: 2026-10-20T09:12:44.123+02:00
date_modified: 2026-10-22T18:01:02.456+02:00         # обновляется при каждой записи
---
Текст заметки.
```

- `previous_task` читается также как строки `"[[Имя]]"` и строки без скобок; пишется объектами `{uid: "[[Имя]]", reltype: FINISHTOSTART}`, как в TaskNotes. «Next tasks» в файле не хранится — это `previous_task` других задач.
- **Ссылка на событие**: строка `eventIdentifier|название|начало ISO 8601` (с часовым поясом). Название может содержать `|` — делятся только первый и последний разделитель. Поиск: по `eventIdentifier` в тот же день (у повторяющихся событий id общий, ближайшее по времени начало), затем по названию и точному времени начала, иначе — «event not found» (значок, связь игнорируется). Скилл может писать любой `eventIdentifier` (например, `skill`), если название и время точные.
- Приложение **не трогает**: `deadline`, `skipped_instances`, `recurrence_anchor` (не удаляет), тег `archived`, `contexts`, `projects`, `timeEntries`, `pomodoros`, любые незнакомые ключи, комментарии и тело (байт-в-байт, покрыто тестами).

## 6. Запись в файлы

`Data/Repositories/VaultTaskRepository.swift`: чтение и запись через `NSFileCoordinator`, атомарно; меняется **только** нужный ключ (`Data/Frontmatter/FrontmatterDocument.swift` — свой редактор подмножества YAML, который Obsidian пишет) плюс `date_modified`. Списки (`*_instances`, `previous_task`) меняются **дельтами** по свежепрочитанному файлу: отметить один день, добавить/убрать/переименовать одну связь; записи, которые приложение не поняло, остаются. Текст, который не разбирается как frontmatter, не записывается никогда.

- Конфликт Mac ↔ iPhone: если файл изменился с момента чтения или у iCloud есть конфликтные версии, правка применяется к **последней** версии файла (побеждает последняя правка), конфликтные версии разрешаются, сверху плашка «Task X was changed in two places, the latest version was kept».
- Удаление — в `.trash` в корне vault (корзина Obsidian), после диалога и бэкапа.
- Переименование — файл + `previous_task` у задач, которые на неё ссылаются (после бэкапа). Ссылки в тексте других заметок не переписываются.
- Бэкапы: App Group → `SuperPooper/Backups/<время>-<причина>/`, хранится `rules.json → backups.keepCount` последних.

## 7. Как добавить поле задачи

1. `Resources/Config/field-mapping.json` → `fields` (+ свойство в `Core/Config/FieldMapping.swift`).
2. Свойство в `Domain/Model/TaskNote.swift` и `case` в `Domain/Model/TaskFieldChange.swift` (+ строка в `applying`).
3. Чтение — `Data/Frontmatter/TaskNoteReader.swift`, запись — `Data/Frontmatter/TaskNoteWriter.swift`.
4. Редактирование — строка в `Features/TaskPage/TaskPropertiesSection.swift` (и чип в `Features/MorningReview` при желании), тексты — `Localizable.xcstrings`.
5. Если поле влияет на порядок — новый `case` в `PoolSortCriterion` (`Domain/Day/PoolSorter.swift`) и строка в `sort.json`.
6. Тесты: чтение/запись в `Tests/Data`, логика в `Tests/Domain`.

## 8. Тесты и тестовый vault

- Шаблоны: `Fixtures/TestVault/TaskNotes/Tasks/*.md` с плейсхолдерами дат (`{{date:+N}}`, `{{weekday:fri}}`, `{{compact:-N}}`, `{{stamp:-N}}`, `{{eventlink:Title|+0 19:00}}`) — описаны в `Tests/Support/TestVaultRenderer.swift`. Даты всегда относительно «сегодня», поэтому фикстуры не протухают.
- Отрендерить в папку: `scripts/render-test-vault.sh <папка> [YYYY-MM-DD]`.
- Unit-тесты (логика, RRULE, frontmatter байт-в-байт, сканер и запись на отрендеренном vault, фейковый iCloud):
  ```bash
  scripts/xcb.sh test -only-testing:SuperPooperTests
  ```
- UI-тесты (тапы, меню, страница задачи, переименование/архив/удаление, пикеры, перетаскивание в разборе, pull-to-refresh) — сначала положить свежий vault в симулятор, после — проверить, что файлы изменились ровно как нужно:
  ```bash
  scripts/sim.sh load-vault && scripts/xcb.sh test -only-testing:SuperPooperUITests && scripts/check-vault-after-ui-tests.sh
  ```
- Тесты состояния приложения (`Tests/App`) работают на in-memory сервисах из `Debug/PreviewModel.swift` — тех же, что у превью экранов.
- Добавить случай в фикстуры: новый `.md` в `Fixtures/TestVault/TaskNotes/Tasks/`, при необходимости — проверка в `Tests/Data`.

## 9. Запуск в симуляторе с тестовыми данными

```bash
scripts/xcb.sh build                     # сборка (DerivedData в .build/)
scripts/sim.sh boot && scripts/sim.sh install && scripts/sim.sh grant
scripts/sim.sh load-vault                # тестовый vault → Documents/TestVault в контейнере приложения
scripts/sim.sh launch -SPVaultPath TestVault -SPSeedDemo -SPSkipOnboarding -SPNow 11:30
scripts/sim.sh screenshot .build/shot.png
```

DEBUG-аргументы (в Release их нет): `-SPVaultPath`, `-SPSeedDemo` (календарь «SuperPooper Test» с событиями 10:00, «Call with dad» 19:00–20:00, повторяющимся «Lunch», лист с напоминанием на 15:00 и лист «Inbox», который приложение игнорирует), `-SPNow HH:mm`, `-SPSkipOnboarding`, `-SPResetState`, `-SPTimeline oneColumn|twoColumns`, `-SPOpen superpooper://…`, `-SPProvisionalNotifications`. Deep links: `superpooper://task/<имя>`, `…://settings`, `…://review`, `…://archive`, DEBUG: `…://debug-notifications`, `…://debug-widgets`. Тестовый vault также можно выбрать вручную: «Файлы» → «На iPhone» → SuperPooper → TestVault.

## 10. Частые поломки

| Симптом | Причина | Что делать |
|---|---|---|
| «Can’t open the vault folder anymore» | bookmark устарел (переименовали/переместили папку, переустановка) | Settings → Sources → Vault folder → выбрать заново |
| Задача пропала, в проблемах «Not downloaded from iCloud yet» | файл выгружен с телефона, не скачался за таймаут | открыть «Файлы», дождаться iCloud, потянуть вниз; таймаут — `rules.json → vault.downloadTimeoutSeconds` |
| Плашка «changed in two places» | правка на Mac и iPhone одновременно | ничего: сохранена последняя версия; бэкап — в App Group |
| Заметка не видна, «Broken YAML» | ошибка в frontmatter (незакрытая кавычка/скобка, табы) | исправить в Obsidian; приложение такие заметки пропускает |
| Событий нет на таймлайне | нет доступа к Calendar или не выбраны календари | Settings → Sources: Calendar access, Anchor calendars |
| «Event not found» у задачи | событие удалили/перенесли на другой день | выбрать событие заново на странице задачи |
| Виджет «Open SuperPooper once…» | нет снимка в App Group или виджет не видит группу | открыть приложение; проверить App Group у обоих таргетов (TRANSFER.md) |
| Экран «Config error» | опечатка в `Resources/Config/*.json` | исправить ключ, указанный на экране |

## 11. Процесс (из манифеста)

- «Релизь» = закоммитить с описанием всего, что появилось с прошлого коммита, и выпустить релиз (git-тег) с буллет-списком всего, что появилось с прошлого релиза.
- Коммиты и релизы — только по команде пользователя.
- После изменений — собрать и поставить в симулятор; в симулятор заходить, только чтобы найти баг, о котором сказал пользователь.
