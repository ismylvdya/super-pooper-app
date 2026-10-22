# SuperPooper

iPhone-приложение для дня, дел и привычек поверх Obsidian TaskNotes, Apple Calendar и Apple Reminders. Своей базы задач нет: задачи — заметки в vault, события — в Calendar, напоминания — в Reminders.

- **Today**: пул дел без времени (не просрачиваются) и таймлайн с линией «сейчас», событиями и цепочками дел вокруг событий.
- **Утренний разбор**: таблица задач пула с чипами свойств и перетаскиванием.
- **Страница задачи**: все поля TaskNotes, связи с задачами и событиями, отметки привычек, текст заметки.
- **Виджеты**: Today (Large) и Habit grid (Small/Medium).
- **Уведомления**: привычки и задачи со временем, напоминания; действия прямо в уведомлении.

Версия: **v0** (0.0.0, сборка 1).

Скриншоты (симулятор, тестовый vault, 11:30): [Today](docs/screenshots/today.png) · [две половины дня](docs/screenshots/today-two-halves.png) · [тёмная тема](docs/screenshots/today-dark.png) · [страница задачи](docs/screenshots/task-page.png) · [утренний разбор](docs/screenshots/morning-review.png) · [настройки](docs/screenshots/settings.png) · [виджеты](docs/screenshots/widgets.png).

## Как открыть и запустить
1. Открыть `SuperPooper.xcodeproj` в Xcode 26.3.
2. В Signing & Capabilities выбрать свою команду у таргетов `SuperPooper` и `SuperPooperWidgets`.
3. Запустить схему `SuperPooper` в симуляторе или на iPhone.

Подробно — **[TRANSFER.md](TRANSFER.md)** (перенос, подпись, AltStore) и **[docs/HANDBOOK.md](docs/HANDBOOK.md)** (как всё устроено и где что менять).

## Карта конфигов: чтобы изменить X — правь Y
Все конфиги — в `Resources/Config/`, проверяются при запуске (опечатка → экран с файлом и ключом).

| Чтобы изменить… | Правь |
|---|---|
| Раскладку Today (пул сверху/слева, доли места) | `layouts/today.layout.json` (`axis`, `blocks`) |
| Отступы, скругления, размеры, шрифты, цвета (светлые/тёмные), длительности | `tokens.json` |
| Иконки | `icons.json`; иконки действий — `actions.json` |
| Действия, подтверждения, вибрации, состав меню и кнопок уведомлений | `actions.json` |
| Порядок сортировки пула | `sort.json` |
| Имена полей TaskNotes, статусы, приоритеты | `field-mapping.json` |
| Включить/выключить функцию | `feature-flags.json` |
| Правила и пороги (оценки, уведомления, бэкапы, виджеты, iCloud) | `rules.json` |
| Настройки по умолчанию | `defaults.json` |
| Тексты | `Resources/Localizable.xcstrings` |
| Bundle ID, App Group, версия | `Config/Shared.xcconfig` |

Подробнее и с примерами — `docs/HANDBOOK.md`, раздел 3.
