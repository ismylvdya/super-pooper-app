# TRANSFER — перенос на свой Mac и установка на iPhone

Для пользователя после копирования папки проекта на свой MacBook (macOS 15.6.1, Xcode 26.3).

## 1. Подготовка папки
1. Удалите `.build/` — там кэши сборки и скачанные для справки исходники TaskNotes, они не нужны:
   ```bash
   trash .build
   ```
   (или просто удалите папку в Finder).
2. Откройте `SuperPooper.xcodeproj` двойным кликом. XcodeGen и другие инструменты не нужны.

> v0 собиралась и проверялась в Xcode 16.4 на iOS 18.6, потому что Xcode 26 на машине сборки не было (подробно — `DECISIONS.md`, D-001). Проект настроен под Xcode 26.3 и iOS 26.0. Если Xcode 26.3 покажет новые предупреждения SDK, они чинятся точечно; можно попросить Claude Code: «собери и убери предупреждения».

## 2. Подпись своим Apple ID
1. Xcode → Settings → Accounts: добавьте свой Apple ID. Появится команда «<Имя> (Personal Team)».
2. Выберите проект `SuperPooper` в навигаторе → таргет **SuperPooper** → Signing & Capabilities → Team: ваш Personal Team. Стиль подписи — Automatically manage signing (уже включён).
3. То же самое для таргета **SuperPooperWidgets**.
4. Проверьте, что у обоих таргетов в Capabilities есть **App Groups** с группой `group.SuperPooperApp` (она берётся из entitlements). Если Xcode пишет, что группа не зарегистрирована, нажмите «+» в App Groups и отметьте её — Xcode зарегистрирует её на ваш аккаунт.

### Если Xcode пишет, что bundle ID или App Group заняты
Поменяйте **одну строку** в `Config/Shared.xcconfig`:
```
SP_BUNDLE_ID = SuperPooperApp
```
например, на `SP_BUNDLE_ID = SuperPooperApp.ismylvdya`. От неё автоматически строятся ID виджета (`….Widgets`), тестов и App Group (`group.…`). После смены — Product → Clean Build Folder и снова выбрать команду, если Xcode её сбросил.

## 3. Запуск в симуляторе
1. Создайте симулятор iPhone 17 Pro (Xcode → Window → Devices and Simulators) или используйте любой.
2. Выберите схему `SuperPooper` и симулятор, нажмите Run.
3. Тестовые данные (необязательно): в Terminal из папки проекта
   ```bash
   SP_SIMULATOR="iPhone 17 Pro" scripts/sim.sh load-vault
   ```
   после первого запуска приложения — тестовый vault появится в «Файлы» → «На iPhone» → SuperPooper → TestVault; выберите его в приложении как vault. В Debug-сборке в настройках есть «Seed demo data» — тестовый календарь и напоминания.

## 4. Первый запуск на телефоне
1. Онбординг по шагам: выберите **папку vault** в iCloud Drive (сам vault Obsidian, внутри которого `TaskNotes/Tasks`) → доступ к Calendar → Reminders → уведомлениям → календари-якоря и листы «вспомнить в X». Inbox-лист не выбирайте — приложение его не трогает.
2. Папка задач и тег берутся из настроек по умолчанию (`TaskNotes/Tasks`, `🔫делишка`) — как в вашем `data.json`.
3. Всё это потом доступно в Settings → Sources.

## 5. Готовый `.ipa` для AltStore
Готовый файл лежит в репозитории: **`dist/SuperPooper.ipa`**. Он подписан ad-hoc: без сертификата, без Team ID, без provisioning profile, без путей машины сборки, так что ничьего Apple ID в нём нет. При установке AltStore (или SideStore) переподписывает приложение **и** расширение виджетов Apple ID того, кто ставит. Внутри — entitlement App Group, AltStore заменит её на группу своего аккаунта.

Варианты установки:
- **Файлом:** перенести `dist/SuperPooper.ipa` на iPhone (AirDrop / «Файлы»), в AltStore → My Apps → «+» → выбрать файл.
- **Через GitHub-источник AltStore:** залить репозиторий на GitHub, в `dist/altstore-source.json` заменить `GITHUB_USER/GITHUB_REPO` на свои, закоммитить. В AltStore → Sources → «+» → `https://raw.githubusercontent.com/<user>/<repo>/master/dist/altstore-source.json`. Новые версии: пересобрать `.ipa`, поднять `version`/`buildVersion`/`date` в JSON, закоммитить.

Пересобрать `.ipa` (Apple ID не нужен):
```bash
scripts/make-ipa.sh
```
Скрипт делает Release-сборку для устройства без подписи, подписывает ad-hoc с entitlements и проверяет, что в бинарниках нет путей машины, Team ID и профилей. Если проверка находит след, скрипт падает.

> `.ipa` v0 собран в Xcode 16.4 (iOS 18.5 SDK) с минимальной iOS 18.0 — он работает и на iOS 26. После сборки в Xcode 26.3 скрипт сам соберёт под iOS 26.0.

Лимиты бесплатного аккаунта: до 3 активных приложений через AltStore; **до 10 App ID за 7 дней** — SuperPooper занимает 2 (приложение + виджеты). App Group AltStore записывает в `Info.plist` под ключом `ALTAppGroups`; приложение и виджет ищут группу сначала там.

## 6. Переподпись раз в неделю
Подпись бесплатного аккаунта живёт 7 дней. AltStore продлевает её сам («Refresh All» вручную или автоматически), когда телефон и Mac с AltServer в одной Wi-Fi-сети. Если подпись истекла, приложение не запустится, но **данные не пострадают**: задачи лежат в Obsidian, события — в Calendar. После переустановки придётся заново выбрать папку vault и календари, а снимок для виджетов пересоберётся при первом открытии.
