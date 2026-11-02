# New Item Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One flow for adding and arranging things: Tasks / Habits / Settings tab bar with its own "+", one new-item page with a Task/Habit slider and chips, inline date detection, an Inbox for the intent, backlog pages left of the pool, pool sections, Select with batch actions (Worm, New section), dragging "+", repeatable subtasks and the time zone picker.

**Architecture:** Screens → `AppModel` façade → parts in `App/State` → pure `Domain` → `TaskStore` → TaskNotes adapter (`Data/TaskNotes`). New pure logic (date detection, sections, backlog contents, page strip, batch availability) lives in `Domain` with Swift Testing tables; new app-only state (sections, worms) lives in the App Group behind its own storage protocol, like `day-state.json`. Every visible number, word, icon and menu comes from `Resources/Config/*` and `Localizable.xcstrings`.

**Tech Stack:** Swift 5 language mode, SwiftUI (min iOS 26 on main; this Mac builds iOS 18.6 through the git-ignored `Config/Local.xcconfig`), Swift Testing (unit), XCTest (UI), EventKit, App Intents.

**Spec:** `docs/superpowers/specs/2026-11-03-new-item-flow-design.md` (Russian). Its last section «Уточнения после проверки исполнителем» overrides earlier text.

## Global Constraints

- Work in `/Users/mdmkudryashov/projects/super-popper-app-flow`, branch `new-flow`. Before Stage 1: `git merge main` (main will already contain `fixes-round3`: `MenuDefinition.frequent/more` in `actions.json`, `DropGhost.swift`, `MenuSections.swift`, `TimelineMinuteLabel.swift`, the `started` property, D-101…D-111). Build on those; never re-add what round 3 removed (`TodayPager.isFinishing`, `TodaySwipe.commits`).
- New DECISIONS entries take the next free `D-NNN` after the last one in `DECISIONS.md` at the time (Russian, existing style). HANDBOOK sections that describe changed behaviour are updated in the same commit.
- Build: `SP_SIMULATOR="iPhone 16 Pro" scripts/xcb.sh build -quiet`. Unit suite: `SP_SIMULATOR="iPhone 16 Pro" scripts/xcb.sh test -only-testing:SuperPooperTests/<Suite>`; success = `Test run with N tests passed` and `** TEST SUCCEEDED **` (XCTest's `Executed 0 tests` is normal). Pipe logs to the scratchpad, grep them. `trash .build/Results/*.xcresult` after each run.
- UI tests: `SP_SIMULATOR="iPhone 16 Pro" scripts/sim.sh install && SP_SIMULATOR="iPhone 16 Pro" scripts/sim.sh load-vault && SP_SIMULATOR="iPhone 16 Pro" scripts/xcb.sh test -only-testing:SuperPooperUITests/<Class>/<test>`; at each stage end the whole `SuperPooperUITests`, then `scripts/check-vault-after-ui-tests.sh`.
- Only the existing "iPhone 16 Pro" simulator. Create/download/install nothing. Simulator runs stay silent. Delete only with `trash`.
- Architecture: a screen never reads files, calls EventKit or decides business rules; it reads `AppModel` and calls its intents. Frontend is replaceable.
- Config instead of literals: numbers/colors/fonts → `tokens.json` (+ `case` in `DesignSystem/Tokens/TokenKeys.swift`), icons → `icons.json` (+ `case` in `Core/Config/IconSet.swift`), actions/menus → `actions.json`, rules/thresholds → `rules.json`, defaults → `defaults.json`, statuses/fields → `field-mapping.json`, lists → `lists.json`, texts → `Localizable.xcstrings`. No `if` on a name or id.
- One file — one responsibility, ~300 lines. No copy-paste. UI text and code comments in English, docs in Russian. Comments only where the code cannot speak.
- Time only from `Clock`/`DayContext`; never `Date()` in logic.
- iOS-26-only API behind `#if compiler(>=6.2)` + `if #available(iOS 26.0, *)` inside `DesignSystem/Platform` (`SystemLook`). Never commit `Local.xcconfig`, never edit `Shared.xcconfig` for the build.
- TaskNotes plugin code is never changed; notes stay in the format TaskNotes writes (HANDBOOK §5). No new TaskNotes knowledge outside `Data/TaskNotes` and `field-mapping.json`.
- Owner's UI rule: never several facts in one line joined by "·", "|", "/", commas. Each fact its own element, icon or color.
- Native first: lifts, swipes, menus, pull-to-refresh, edit selection look and behave as iOS draws them. The only own-drawn control is the "+" bubble.
- Owner's terms in UI: Tasks, Habits, Settings, Soon, Someday, Inbox, Morning, Day, Evening, Worm, New section, Select, Unworm. The Half year page shows its `lists.json` title (`status.halfYear`) as is (spec: «беру существующий статус и его название»).
- Commit after each green task: `git add -A && git commit` with an English subject saying what is now true, optional `- ` bullets, and the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Each stage ends green and committable on its own.
- A failing test is a blocker even if it was not yours: fix it (wrong assert, outdated expectation, flaky timing), never skip or disable.
- Looks that depend on system drawing (tab bar bubbles, drag lift, segmented control, edit circles) may differ between the iOS 18.6 simulator and the owner's iOS 26 phone: set shapes explicitly and list them in the stage report as "check on the phone".

## Review Focus

1. **Date words inside ordinary names** — "Buy monitor", "Call Monica", "Room 6.11b", "May I ask", "in 2 boxes", "Read 1984" must not be detected; only whole words of the grammar, a month only next to a day number, `in N` only with a grammar unit. Test: `DateDetectorTests.ordinaryWordsAreNotDates` (Task 3.2).
2. **Impossible dates and times** — "31.02", "29.02.2027", "25:10", "6:75", "13pm" detect nothing rather than roll over. Test: `DateDetectorTests.impossibleDatesAreNotDetected` (Task 3.2).
3. **The logical day around midnight** — at 01:30 (before the 04:00 boundary) "today" is the logical today, "tomorrow" the next logical day, "18:20" today's evening, "01:00" the coming 01:00 tonight. Test: `DateDetectorTests.beforeTheBoundaryTheLogicalDayCounts` (Task 3.2).
4. **A name that is only a date** — accepting "tomorrow" on the page, or the intent "tomorrow 18:00", would leave an empty name: the text stays the name and the date is still set. Tests: `NewItemPageTests.acceptingTheWholeNameKeepsItAsTheName` (Task 3.3), `NewTaskIntentTests.aNameThatIsOnlyADateStaysTheName` (Task 3.5).
5. **Renamed and deleted notes in app-only day state** — sections and worms refer to note names: a rename must follow, a delete must leave no ghost member, Undo must bring membership back. Tests: `DaySectionsControllerTests.aRenameFollowsAndADeleteLeaves` (Task 5.4), `UndoTests.undoingABatchDeleteBringsBackSectionsAndWorms` (Task 6.2).

---

## File Structure (new files)

| File | Responsibility |
|---|---|
| `App/TabBarItem.swift` | the tab bar's selection: a tab or the reserved "+" slot |
| `App/NewItemButton.swift` | own glass "+" bubble: tap opens the new-item page, long press drags |
| `App/State/Tasks/NewItemPage.swift` (replaces `NewNotePage.swift`) | new-item page state: kind, name, drafts per kind, detected/accepted date, placement |
| `Domain/Model/NewItemSeed.swift` | what a "+" opens: kind and optional placement |
| `Domain/Model/NewItemPlacement.swift` | where a dragged "+" landed: timeline moment or pool spot |
| `Features/Common/NewItemScreen.swift` (replaces `NewNoteScreen.swift`) | the page: segmented Task/Habit over the existing sections |
| `Features/TaskPage/TaskChipRows.swift` (replaces `TaskQuickChips.swift`) | three chip rows |
| `Features/TaskPage/DuePickerSheet.swift`, `Domain/Model/DuePick.swift` | calendar + time + Time zone sheet and its pure edits |
| `Core/Config/DateGrammar.swift`, `Resources/Config/date-grammar.json` | words and formats of date detection |
| `Domain/Dates/DateDetector.swift`, `Domain/Dates/DetectedDate.swift` | pure detection |
| `DesignSystem/Components/HighlightingTitleField.swift` | UIKit title field that colours detected ranges and reports their rects |
| `Domain/Lists/BacklogContents.swift` | what Soon / Half year / Someday pages hold for a shown day |
| `Features/Today/TasksPageStrip.swift` | the pages of the Tasks tab: backlog pages + Today content |
| `Domain/Gestures/PullArming.swift`, `DesignSystem/Components/PullIndicator.swift` | one arming rule and indicator for vertical and sideways pulls |
| `Features/Today/BacklogPage.swift`, `Features/Today/BacklogDropDelegate.swift` | a backlog page and dropping on it |
| `Domain/Day/Sections/DaySections.swift`, `PoolSectionDefinition.swift`, `PoolArrangement.swift`, `SectionDropOrder.swift` | sections and worms as data, arranging the pool by them |
| `Core/Storage/DaySectionStore.swift` | protocol + `JSONDaySectionStore` (`day-sections.json`) |
| `App/State/Day/DaySectionsController.swift` | today's and other days' snapshots, rename/delete following |
| `DesignSystem/Components/SectionHeader.swift` | the one section header of the app |
| `Features/Today/PoolSelection.swift`, `Features/Today/SelectionToolbar.swift` | Select mode state and its bar buttons |
| `Domain/Actions/BatchAvailability.swift` | which batch actions the selected items offer |
| `Domain/Day/RepeatableSubtasks.swift` | membership and rule following of repeatable subtasks |

---

## Stage 1 — Tab bar, own "+", Today's top

### Task 1.1: Router with three tabs, Lists page and new-item routes

**Files:**
- Modify: `App/State/Router.swift`
- Create: `Domain/Model/NewItemSeed.swift`
- Modify: `Resources/Localizable.xcstrings` (`tab.today` value → "Tasks"; key kept so deep links and identifiers stay)
- Test: `Tests/App/RouterTests.swift`

**Interfaces:**
- Produces: `enum AppTab: String, CaseIterable { case today, habits, settings }` (`lists` removed); `enum Route` gains `case lists` and `case newItem(NewItemSeed)`, loses `newTask`, `newHabit`; `struct NewItemSeed: Hashable, Sendable { enum Kind: Hashable, Sendable { case task, habit }; var kind: Kind; var placement: NewItemPlacement? = nil; static func opening(on tab: AppTab) -> NewItemSeed }`; `Router.openNewItem(_ seed: NewItemSeed? = nil)` (pushes `.newItem(seed ?? .opening(on: tab))` on the current tab); `Router.tasksTaps` (renamed `todayTaps`).
- `NewItemPlacement` is declared in Task 7.2; until then `NewItemSeed` has only `kind` (add `placement` there).

- [ ] **Step 1: Write the failing tests**

```swift
@Test func theTabBarHasTasksHabitsAndSettings() {
    #expect(AppTab.allCases == [.today, .habits, .settings])
}
@Test func plusOpensAHabitInHabitsAndATaskElsewhere() {
    #expect(NewItemSeed.opening(on: .habits).kind == .habit)
    #expect(NewItemSeed.opening(on: .today).kind == .task && NewItemSeed.opening(on: .settings).kind == .task)
    let router = Router(); router.select(.settings); router.openNewItem()
    #expect(router.path == [.newItem(NewItemSeed(kind: .task))])
}
@Test func listsLinksOpenTheListsPageOnTasks() throws {
    let list = try routed("superpooper://lists/someday")
    #expect(list.tab == .today && list.path == [.lists, .list("someday")])
    #expect(try routed("superpooper://lists").path == [.lists])
}
// reviewAndNewTaskLinks: new-task → path == [.newItem(NewItemSeed(kind: .task))]
```

- [ ] **Step 2: Run** `SP_SIMULATOR="iPhone 16 Pro" scripts/xcb.sh test -only-testing:SuperPooperTests/RouterTests` — FAIL (no `NewItemSeed`, `.lists`).
- [ ] **Step 3: Implement** the router changes; `RootView.destination` maps `.lists` → `ListsScreen()` and `.newItem(seed)` → `NewNoteScreen(kind: seed.kind == .habit ? .habit : .task, tab: tab)` for now; `root(_:)` loses `.lists`; `AppTab.icon(lists:)` loses `.lists`; `IconSet.otherTabSymbols` keeps working on three tabs. Fix every compile error the removed routes cause (TaskListScreen, HabitsScreen, TodayButtons, MorningReviewScreen buttons are removed in Task 1.3 — here route them to `openNewItem()` only to compile).
- [ ] **Step 4: Run** the suite — PASS; then the whole `SuperPooperTests`.
- [ ] **Step 5: Commit** `Tabs: Tasks, Habits and Settings; Lists is a page and "+" has its own route`

### Task 1.2: Own "+" bubble beside the system tab bar (upright and lying sideways)

**Files:**
- Create: `App/TabBarItem.swift`, `App/NewItemButton.swift`
- Modify: `App/RootView.swift`, `App/LandscapeTabBar.swift`, `DesignSystem/Platform/SystemLook.swift` (+ `ClassicLook.swift`, `LiquidGlassLook.swift`), `Resources/Config/tokens.json` (`systemBar.metric.newItemBubble`, `newItemBubbleInset`), `Resources/Config/icons.json` (`newItem: "plus"`), `IconSet.swift`, `TokenKeys.swift`
- Test: `Tests/App/TabBarItemTests.swift`; UI: `UITests/NewTaskUITests.swift`

**Interfaces:**
- Produces: `enum TabBarItem: Hashable { case tab(AppTab); case newItem }`, `static func selection(_ item: TabBarItem, router: Router)` — `.tab` → `router.select`, `.newItem` → `router.openNewItem()` (the selection never stays on `.newItem`); `SystemLook.newItemBubble`; `NewItemButton(drag: TaskDragState?)` with accessibility identifier `"tabBar.newItem"`.

Decision (spec leaves it to the builder): upright, the system `TabView` keeps its native tab bar and gets a fourth `Tab(value: TabBarItem.newItem, role: .search)` whose only job is to make the system reserve the separate bubble on the right (iOS 26 draws search-role tabs apart; iOS 18 puts it last). `NewItemButton` is overlaid exactly on that bubble (size `newItemBubble`, trailing/bottom insets from `systemBar.metric`) with `.systemLook(.newItemBubble)` (Liquid Glass on iOS 26, material on iOS 18), so tap and long-press-drag are ours while the room is the system's. Lying sideways, `LandscapeTabBar` ends with a `NewItemButton` in its own capsule at the physical end of the column. Record as a D-entry; list the bubble alignment as "check on the phone".

- [ ] **Step 1: Write the failing test**

```swift
@MainActor struct TabBarItemTests {
    @Test func theReservedSlotOpensTheNewItemPageAndKeepsTheTab() {
        let router = Router(); router.select(.habits)
        TabBarItem.selection(.newItem, router: router)
        #expect(router.tab == .habits && router.path == [.newItem(NewItemSeed(kind: .habit))])
    }
    @Test func aTabIsSelectedAsBefore() {
        let router = Router()
        TabBarItem.selection(.tab(.settings), router: router)
        #expect(router.tab == .settings)
    }
}
```

- [ ] **Step 2: Run** `…/TabBarItemTests` — FAIL.
- [ ] **Step 3: Implement** `TabBarItem`, the reserved tab in `RootView` (selection binding `TabBarItem`), `NewItemButton` (a `Button` for tap; drag source is added in Task 7.3), the landscape button.
- [ ] **Step 4: Run** the suite — PASS.
- [ ] **Step 5: UI test** `testPlusOnEveryTabOpensTheNewItemPage`: tap `tabBar.newItem` on Tasks → the page's `taskPage.name` field is focused; Back; Habits tab → `tabBar.newItem` → page title placeholder "New habit". Run it — PASS.
- [ ] **Step 6: Commit** `Tab bar: a glass "+" beside the tabs opens a new task, or a habit in Habits`

### Task 1.3: Today's top: Lists on the left with the problems badge, search on the right; old "+" buttons gone

**Files:**
- Modify: `Features/Today/TodayButtons.swift`, `Features/Today/TodayScreen.swift`, `Features/Today/TodayPager.swift`, `Features/Lists/ListsScreen.swift`, `Features/Lists/TaskListScreen.swift`, `Features/Habits/HabitsScreen.swift`, `Features/MorningReview/MorningReviewScreen.swift`, `Resources/Config/tokens.json` (`size.problemBadge`, `color.problem` reused)
- Test: `Tests/Features/TodayPagerTests.swift`, `Tests/Features/TodayButtonsTests.swift`; UI: `UITests/TodayUITests.swift`, `UITests/NewTaskUITests.swift`

**Interfaces:**
- Produces: `TodayButtons.Placement.items` → leading `[.lists]`, trailing `[.search]`; `TodayButtons.Item { case lists, search }`; `TodayButtons.badgeCount(problemCount: Int, flagOn: Bool) -> Int?` (nil = no badge); `TodayPager.showPool(animation:)` = today's date + the pool page (used by the Tasks tab tap and the day title tap); `ListsScreen` is nested (`isNested: true`, Back) and its first plate is a Problems row (`problems.title`, count in its own accessory, problem color) shown only with problems, opening `router.isProblemsPresented`.
- Morning review keeps opening by itself once a day (`claimMorningReview`) and has no button and no "+" any more.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func theTasksTabAndTheDayTitleBringBackThePoolOfToday() {
    let pager = TodayPager()
    pager.turn(to: 1, pageCount: 2, animation: .default)
    pager.showPool(animation: .default)
    #expect(pager.page == 0 && pager.dayOffset == 0)
}
@Test func theBadgeShowsOnlyProblemsWhenTheFlagIsOn() {
    #expect(TodayButtons.badgeCount(problemCount: 3, flagOn: true) == 3)
    #expect(TodayButtons.badgeCount(problemCount: 0, flagOn: true) == nil)
    #expect(TodayButtons.badgeCount(problemCount: 3, flagOn: false) == nil)
}
```

- [ ] **Step 2: Run** `…/TodayPagerTests` and `…/TodayButtonsTests` — FAIL.
- [ ] **Step 3: Implement**: the lists button shows `icons[model.listsIcon]` through `IconGlyph`, the badge is a yellow capsule with the count over its top trailing corner (`.overlay`, token `size.problemBadge`), tap → `router.open(.lists)`; the day title stays `.principal`; `router.tasksTaps` → `pager.showPool`; `DayNavigation` today-tap → `showPool`. Remove `today.newTask`, `today.review`, Habits "+", list "+", review "+" buttons and their now-unused strings.
- [ ] **Step 4: Run** both suites — PASS; whole `SuperPooperTests`.
- [ ] **Step 5: UI tests**: update every `today.newTask` / `today.review` use in `UITests/*` to `tabBar.newItem` / the review link; new `testListsButtonPushesListsWithBack` (tap `today.lists` → nav bar "Lists" with a Back button → Back → Today); `testSomedayListAddsATaskToSoon` keeps working through `today.lists`. Run `NewTaskUITests` and `TodayUITests` — PASS.
- [ ] **Step 6: Stage gate**: D-entry «Таб-бар Tasks / Habits / Settings и своя кнопка "+"» (reserved search slot, Lists as a page, problems badge, review only by itself); HANDBOOK §2 (RootView), §3 (new tokens/icons), §4.3 top of Today; full UI suite + vault check.
- [ ] **Step 7: Commit** `Today: Lists on the left with the problems badge, search on the right; "+" lives only beside the tabs`

---

## Stage 2 — New-item page

### Task 2.1: `NewItemPage`: one page for both kinds, the name survives a switch

**Files:**
- Create: `App/State/Tasks/NewItemPage.swift`; trash `App/State/Tasks/NewNotePage.swift`
- Modify: `App/State/Tasks/NoteCommands.swift` (`create(from:)`, `createOnReturn(from:)`, `createTask(named:)` take `NewItemPage`), `App/State/AppModel+Tasks.swift`
- Test: rename `Tests/App/NewNotePageTests.swift` → `Tests/App/NewItemPageTests.swift` (keep all existing cases, ported)

**Interfaces:**
- Produces:
```swift
struct NewItemPage: Equatable {
    var kind: NewItemSeed.Kind
    var name = ""
    var draft: NoteDraft { get set }            // the current kind's draft
    init(kind: NewItemSeed.Kind, taskDraft: NoteDraft, habitDraft: NoteDraft)
    func nameProblem(_ rules: (String) -> NoteNameProblem?) -> NoteNameProblem?
    func creation(unnamed: String, rules: (String) -> NoteNameProblem?) -> (draft: NoteDraft, name: String)?
    func savedOnReturn(rules: (String) -> NoteNameProblem?) -> (draft: NoteDraft, name: String)?
}
```
Decision: switching kind keeps both drafts, so switching back restores what was set; only the shown kind is created.

- [ ] **Step 1: Write the failing tests** (plus the ported ones)

```swift
@Test func switchingKindKeepsTheNameAndEachKindsDraft() {
    var page = NewItemPage(kind: .task, taskDraft: .newTask, habitDraft: habitDraft)
    page.name = "Stretch"; page.draft.apply([.highPriority(true)])
    page.kind = .habit
    #expect(page.name == "Stretch" && page.draft == habitDraft)
    page.kind = .task
    #expect(page.draft.changes == [.highPriority(true)])
}
@Test func onlyTheShownKindIsCreated() throws {
    var page = NewItemPage(kind: .task, taskDraft: .newTask, habitDraft: habitDraft)
    page.name = "Stretch"; page.kind = .habit
    #expect(try #require(page.savedOnReturn(rules: names.problem(in:))).draft.note.status == .habit)
}
```

- [ ] **Step 2: Run** `…/NewItemPageTests` — FAIL.
- [ ] **Step 3: Implement**; `NoteCommands.newItemPage(kind:) -> NewItemPage` builds both drafts (`NoteDraft.newTask`, `newHabitDraft()`).
- [ ] **Step 4: Run** `…/NewItemPageTests`, `…/SaveOnReturnTests`, `…/NewTaskIntentTests` — PASS.
- [ ] **Step 5: Commit** `New item page: one draft per kind, the typed name kept across Task and Habit`

### Task 2.2: `NewItemScreen` with the Task / Habit slider

**Files:**
- Create: `Features/Common/NewItemScreen.swift`; trash `Features/Common/NewNoteScreen.swift`
- Modify: `App/RootView.swift` (`.newItem(seed)` → `NewItemScreen(seed: seed, tab: tab)`), `Resources/Localizable.xcstrings` (`newItem.kind.task` "Task", `newItem.kind.habit` "Habit")
- UI: `UITests/NewTaskUITests.swift`

**Interfaces:**
- Consumes: `NewItemPage`, `AppModel.newItemPage(kind:)`, `createOnReturn(from:)`, `create(from:unnamed:)`.
- The slider is a native `Picker(selection:) { … }.pickerStyle(.segmented)` (identifier `newItem.kind`) directly under the title; under it `TaskSections` or `HabitSections` exactly as today. Behaviour of Return, Back and "another tab only hides the page" is unchanged.

- [ ] **Step 1: UI test** `testSwitchingToHabitKeepsTheTypedName`: open `tabBar.newItem`, type "Stretch", tap segment "Habit" → field still "Stretch", Habit sections visible (`habitPage.timeOfDay` row exists); Return → banner "Created Stretch" and the note is a habit (its page shows the history section). Run — FAIL.
- [ ] **Step 2: Implement** the screen.
- [ ] **Step 3: Run** `NewTaskUITests` — PASS (all old cases ported to the new entry point).
- [ ] **Step 4: Commit** `New item page: a Task / Habit slider over the page, the name stays when switching`

### Task 2.3: Three chip rows; chip facts leave Properties

**Files:**
- Create: `Features/TaskPage/TaskChipRows.swift`, `Domain/Model/FeelChip.swift`; trash `Features/TaskPage/TaskQuickChips.swift`
- Modify: `Features/TaskPage/TaskSections.swift`, `Features/TaskPage/TaskPropertiesSection.swift`, `Features/Common/QuickDueLook.swift`, `Resources/Config/icons.json` (`datePick: "calendar"`), `Localizable.xcstrings`
- Test: `Tests/Domain/FeelChipTests.swift`, `Tests/Domain/QuickPlanningTests.swift`

**Interfaces:**
- Produces: `enum FeelChip: CaseIterable { case pleasant, needEnergy; var feel: TaskFeel; static func toggling(_ chip: FeelChip, current: TaskFeel) -> TaskFeel }`; `TaskChipRows(editor:)` rows: 1) High priority (`taskPage.chip.high`); 2) Today, Tomorrow, date-pick chip (`taskPage.chip.date`: round calendar icon; with a due on another day than Today/Tomorrow it shows the date as its title via `DateText`); 3) Pleasant (`icons.pleasant`), Need energy (`icons.energy`, the frog).
- Decision: the rows are shared by the new-item page and the task page (`TaskSections` is shared); for a task, Properties no longer shows High, Due, Feel and Time zone (they live in the chips and the date sheet, .2471). A habit's Properties keep High, estimate, feel (habits have no chips).

- [ ] **Step 1: Write the failing tests**

```swift
@Test func aFeelChipTurnsItsFeelOnAndOff() {
    #expect(FeelChip.toggling(.pleasant, current: .neutral) == .pleasant)
    #expect(FeelChip.toggling(.pleasant, current: .pleasant) == .neutral)
    #expect(FeelChip.toggling(.needEnergy, current: .pleasant) == .needEnergy)
}
@Test func theDateChipIsOnlyForAnotherDayThanTodayOrTomorrow() {
    let context = TestCalendar.context(at: "2026-11-04 11:30")
    #expect(QuickDue.selection(of: TaskDue(day: LocalDate("2026-11-06")), context: context) == nil)
    #expect(DateChip.title(for: TaskDue(day: LocalDate("2026-11-06")), context: context) != nil)
    #expect(DateChip.title(for: TaskDue(day: LocalDate("2026-11-05")), context: context) == nil)
}
```
(`DateChip.title(for:context:) -> LocalDate?` lives in `Domain/Model/QuickDue.swift`.)

- [ ] **Step 2: Run** `…/FeelChipTests`, `…/QuickPlanningTests` — FAIL.
- [ ] **Step 3: Implement**; each row an `HStack` of `ToggleChip`s centred, rows in a `VStack(spacing: chipGap)`.
- [ ] **Step 4: Run** both suites — PASS; UI `TaskPageUITests` updated (`taskPage.high` toggle → `taskPage.chip.high`) — PASS.
- [ ] **Step 5: Commit** `Task chips: High, then Today, Tomorrow and a date, then Pleasant and Need energy; Properties no longer repeat them`

### Task 2.4: Date sheet: calendar, time, Time zone (None by default)

**Files:**
- Create: `Features/TaskPage/DuePickerSheet.swift`, `Domain/Model/DuePick.swift`
- Modify: `Features/TaskPage/TimeZoneRow.swift` (extract `TimeZonePicker` to be reused; row label for no zone → `taskPage.timeZone.none` "None"), `Features/TaskPage/TaskChipRows.swift`, `Localizable.xcstrings`
- Test: `Tests/Domain/DuePickTests.swift`

**Interfaces:**
- Produces: `struct DuePick: Equatable { var day: LocalDate; var time: LocalTime?; var zone: String?; init(task: TaskItem, today: LocalDate); func edits(from task: TaskItem) -> [TaskEdit] }` — `.due(TaskDue(day:time:))` always, `.timeZone(zone)` only when `zone != task.timeZone`; `DuePickerSheet(editor:)` = graphical `DatePicker` (date), time toggle + `TimeField`, Time zone row (zone choice enabled only with a time), Clear and Done in its bar.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func withoutAZoneNothingAboutZonesIsWritten() {
    let task = makeTask("Pay rent")
    var pick = DuePick(task: task, today: LocalDate("2026-11-04"))
    pick.day = LocalDate("2026-11-06"); pick.time = LocalTime("18:20")
    #expect(pick.edits(from: task) == [.due(TaskDue(day: LocalDate("2026-11-06"), time: LocalTime("18:20")))])
}
@Test func aChosenZoneIsWritten() {
    var pick = DuePick(task: makeTask("Call"), today: LocalDate("2026-11-04"))
    pick.time = LocalTime("09:00"); pick.zone = "Asia/Tokyo"
    #expect(pick.edits(from: makeTask("Call")).contains(.timeZone("Asia/Tokyo")))
}
@Test func theSheetStartsAtTheTasksDueOrToday() {
    #expect(DuePick(task: makeTask("X"), today: LocalDate("2026-11-04")).day == LocalDate("2026-11-04"))
}
```

- [ ] **Step 2: Run** `…/DuePickTests` — FAIL.
- [ ] **Step 3: Implement** (edits go through `editor.apply`, so the draft and a note page behave the same).
- [ ] **Step 4: Run** — PASS. UI test `testTheDateChipSetsADayAndShowsIt`: chip `taskPage.chip.date` → pick a day two days ahead → Done → the chip's label is that date. PASS.
- [ ] **Step 5: Stage gate**: D-entry «Страница создания: слайдер, три ряда чипов, лист даты с Time zone»; HANDBOOK new-note section; full UI suite.
- [ ] **Step 6: Commit** `Date chip: a sheet with the calendar, the time and a Time zone that is None unless chosen`

---

## Stage 3 — Date detection, Inbox, intent

### Task 3.1: `date-grammar.json` and its loader

**Files:**
- Create: `Resources/Config/date-grammar.json`, `Core/Config/DateGrammar.swift`
- Modify: `Core/Config/AppConfig.swift` (`File.dateGrammar`, `let dateGrammar: DateGrammar`), `Debug/PreviewModel.swift`/test config helpers if they build `AppConfig` by hand
- Test: `Tests/Core/ConfigTests.swift`

**Interfaces:**
- Produces:
```swift
struct DateGrammar: Codable, Hashable, Sendable {
    let relativePrefix: [String]          // ["in"]
    let units: [Unit: [String]]           // minute: ["min","mins","minute","minutes"], hour: ["h","hour","hours"], day: ["day","days"]
    let today: [String]; let tomorrow: [String]; let nextWeek: [String]
    let weekdays: [Weekday: [String]]     // monday: ["mon","monday"], …
    let months: [Int: [String]]           // 11: ["nov","november"], …
    let at: [String]                      // ["at"]
    let am: [String]; let pm: [String]    // ["am"], ["pm"]
    let dateSeparators: [String]          // ["."]
    let timeSeparator: String             // ":"
    enum Unit: String, Codable, CaseIterable { case minute, hour, day }
    func validate(file: String) throws    // every unit, weekday and month 1…12 present, no word in two groups
}
```

- [ ] **Step 1: Failing test** `ConfigTests.theDateGrammarHasEveryWeekdayMonthAndUnit` (load bundled config; `#expect(config.dateGrammar.months.keys.sorted() == Array(1...12))`, `#expect(Set(config.dateGrammar.weekdays.keys) == Set(Weekday.allCases))`) and `aWordInTwoGroupsIsAConfigError` (`#expect(throws: ConfigError.self) { try grammar(withTodayAlso: "mon").validate(file: "date-grammar.json") }`).
- [ ] **Step 2: Run** `…/ConfigTests` — FAIL.
- [ ] **Step 3: Implement**, load and validate in `AppConfig.load`.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `Date detection: its words and formats come from date-grammar.json`

### Task 3.2: `DateDetector` (pure, table-tested)

**Files:**
- Create: `Domain/Dates/DateDetector.swift`, `Domain/Dates/DetectedDate.swift`
- Test: `Tests/Domain/DateDetectorTests.swift`

**Interfaces:**
- Produces:
```swift
struct DetectedDate: Equatable, Sendable {
    let ranges: [Range<String.Index>]   // one for the date part, one for the time part; adjacent parts merge into one
    let due: TaskDue
}
struct DateDetector: Sendable {
    let grammar: DateGrammar
    func detect(in text: String, context: DayContext) -> DetectedDate?
    /// `text` without the detected ranges, single spaces, trimmed.
    static func removing(_ detected: DetectedDate, from text: String) -> String
}
```
Decisions: words match whole and case-insensitive; a month name needs a day number next to it; `D.M` / `D.M.YYYY` is day.month; a date without a year is the next such day from today (this year or the next); a weekday word is the next such day strictly after today; "next week" is the first day of the next week of the app calendar; `in N min|hours` give date and time (rounded down to the minute), `in N days` a date only; any `H:MM` is 24-hour; "at H" is H:00 24-hour; "Hpm"/"Ham" optional 12-hour; time without date = the nearest future such moment by the logical day (today if not passed, else tomorrow); date without time = no time; the first match of each part wins.

- [ ] **Step 1: Write the failing tests** — one parameterized table (now = Wed 2026-11-04 11:30, boundary 04:00) plus the Review Focus cases:

```swift
@Test(arguments: [
    ("Call mom in 5 min", "2026-11-04", "11:35", "in 5 min"),
    ("Pay rent in 2 hours", "2026-11-04", "13:30", "in 2 hours"),
    ("Pay rent in 3 days", "2026-11-07", nil, "in 3 days"),
    ("Dentist today", "2026-11-04", nil, "today"),
    ("Dentist tomorrow 18:20", "2026-11-05", "18:20", "tomorrow 18:20"),
    ("Gym mon", "2026-11-09", nil, "mon"), ("Gym Monday", "2026-11-09", nil, "Monday"),
    ("Plan next week", "2026-11-09", nil, "next week"),
    ("Visa 6 Nov", "2026-11-06", nil, "6 Nov"), ("Visa Nov 6", "2026-11-06", nil, "Nov 6"),
    ("Visa 6.11", "2026-11-06", nil, "6.11"), ("Visa 06.11.2026", "2026-11-06", nil, "06.11.2026"),
    ("Visa 3.11", "2027-11-03", nil, "3.11"),
    ("Run 6:20", "2026-11-05", "06:20", "6:20"), ("Run 18:20", "2026-11-04", "18:20", "18:20"),
    ("Run at 6", "2026-11-05", "06:00", "at 6"), ("Run 6pm", "2026-11-04", "18:00", "6pm"),
])
func detects(text: String, day: String, time: String?, matched: String) throws {
    let found = try #require(detector.detect(in: text, context: wednesday))
    #expect(found.due == TaskDue(day: LocalDate(day), time: time.map(LocalTime.init)))
    #expect(found.ranges.map { String(text[$0]) }.joined(separator: " ") == matched)
}
@Test func ordinaryWordsAreNotDates() {
    for text in ["Buy monitor", "Call Monica", "Room 6.11b", "May I ask", "in 2 boxes", "Read 1984", "Todayish"] {
        #expect(detector.detect(in: text, context: wednesday) == nil, "\(text)")
    }
}
@Test func impossibleDatesAreNotDetected() {
    for text in ["Due 31.02", "Due 29.02.2027", "At 25:10", "At 6:75", "At 13pm"] { #expect(detector.detect(in: text, context: wednesday) == nil) }
}
@Test func beforeTheBoundaryTheLogicalDayCounts() throws {
    let night = TestCalendar.context(at: "2026-11-05 01:30") // still logical 2026-11-04
    #expect(try #require(detector.detect(in: "X today", context: night)).due.day == LocalDate("2026-11-04"))
    #expect(try #require(detector.detect(in: "X tomorrow", context: night)).due.day == LocalDate("2026-11-05"))
    #expect(try #require(detector.detect(in: "X 18:20", context: night)).due == TaskDue(day: LocalDate("2026-11-05"), time: LocalTime("18:20")))
}
@Test func removingLeavesTheRestOfTheName() throws {
    let text = "Dentist tomorrow at 6pm please"
    #expect(DateDetector.removing(try #require(detector.detect(in: text, context: wednesday)), from: text) == "Dentist please")
}
```
(`TaskDue` is the calendar date and time; build it with `context.due(onLogicalDay:time:)`, so a time before the boundary lands on the next calendar date of its logical day.)

- [ ] **Step 2: Run** `…/DateDetectorTests` — FAIL.
- [ ] **Step 3: Implement** with `NSRegularExpression` built once per grammar (words escaped, joined by `|`, `\b…\b`), validating numbers with `Calendar` (`DateComponents.isValidDate(in:)`).
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `Date detection: relative times, days, dates and 24-hour times found in a name, the logical day respected`

### Task 3.3: Blue suggestion in the name; a tap sets the date and takes the words out

**Files:**
- Create: `DesignSystem/Components/HighlightingTitleField.swift`
- Modify: `App/State/Tasks/NewItemPage.swift`, `Features/Common/NewItemScreen.swift`, `Features/Common/NewNoteNameField.swift` (uses the new field on the new-item page; the task page keeps `TitleTextField`), `App/State/AppModel+Tasks.swift` (`detectDate(in:) -> DetectedDate?` via `parts.notes`/a `DateDetector` built from `config.dateGrammar`), `tokens.json` (`color.detectedDate` → system blue, `size.detectedDateTapRoom`)
- Test: `Tests/App/NewItemPageTests.swift`; UI: `UITests/NewTaskUITests.swift`

**Interfaces:**
- Produces: `NewItemPage.accept(_ detected: DetectedDate)` — sets `.due(detected.due)` on the task draft and sets `name = DateDetector.removing(detected, from: name)`, except when that leaves nothing: then the name stays as typed; `HighlightingTitleField(text:placeholder:highlights:[Range<String.Index>], color:, onReturn:, onHighlightFrames: ([CGRect]) -> Void)` — `UIViewRepresentable` over `UITextView` (centred, wrapping, Return ends editing, `attributedText` colours highlights), reports each highlight's `firstRect(for:)` in its own space. `NewItemScreen` lays a clear `Button` (identifier `newItem.detectedDate`, label = the date's words) over each rect, expanded by `detectedDateTapRoom` above and below.
- Decision (spec): without a tap the date is not set when saving; detection runs only for the Task kind.

- [ ] **Step 1: Failing tests**

```swift
@Test func acceptingADateSetsItAndTakesTheWordsOut() throws {
    var page = taskPage(named: "Dentist tomorrow 18:20")
    let found = try #require(detector.detect(in: page.name, context: wednesday))
    page.accept(found)
    #expect(page.name == "Dentist" && page.draft.note.due == found.due)
}
@Test func acceptingTheWholeNameKeepsItAsTheName() throws {
    var page = taskPage(named: "tomorrow")
    page.accept(try #require(detector.detect(in: page.name, context: wednesday)))
    #expect(page.name == "tomorrow" && page.draft.note.due?.day == LocalDate("2026-11-05"))
}
@Test func aSuggestionNotTappedIsNotSaved() throws {
    let page = taskPage(named: "Dentist tomorrow")
    #expect(try #require(page.savedOnReturn(rules: names.problem(in:))).draft.note.due == nil)
}
```

- [ ] **Step 2: Run** `…/NewItemPageTests` — FAIL.
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Run** — PASS. UI test `testTappingTheBlueDateSetsItAndCleansTheName` (launch `-SPNow 11:30`; type "Dentist tomorrow"; tap `newItem.detectedDate`; field reads "Dentist"; the Tomorrow chip is selected). PASS.
- [ ] **Step 5: Commit** `New task: a date in the name is shown in blue, and a tap on it sets the date and takes the words out`

### Task 3.4: Inbox status and list

**Files:**
- Modify: `Domain/Model/TaskStatus.swift` (`case inbox`; `Name.inbox`; `open = [.inbox, .thisWeek, .halfYear, .someday, .waiting]`), `Resources/Config/field-mapping.json` (`statuses.inbox: "inbox"`), `Data/TaskNotes/FieldMapping.swift`, `Resources/Config/lists.json` (statuses group: `inbox` first, icon `listInbox`), `icons.json` (`listInbox: "tray"`), `IconSet.swift`, `Features/TaskPage/StatusText.swift`, `Localizable.xcstrings` (`status.inbox` "Inbox"), `reference/tasknotes/data.json` (customStatuses: `inbox`, order 0, others shifted — the plugin settings the owner copies), `Fixtures/TestVault/TaskNotes/Tasks/Входящая мысль.md` (status `inbox`)
- Test: `Tests/Data/FieldMappingTests.swift`, `Tests/Data/TaskNoteReaderTests.swift`, `Tests/Domain/TaskListFilterTests.swift`, `Tests/Domain/DayMembershipTests.swift`, `Tests/Domain/FixtureDayPlanTests.swift` (fixture counts)

**Interfaces:**
- Produces: `TaskStatus.inbox`; `AutoPromoter` and `DayMembership` unchanged (inbox is never in a day: membership only takes `thisWeek`). HANDBOOK §1 table: Reminders' "Inbox" list and the "📥 New in inbox" shortcut stay as they are and are still not read.

- [ ] **Step 1: Failing tests**: `FieldMappingTests.inboxReadsAndWritesAsInbox` (`mapping.status(fromRaw: "inbox") == .inbox`, `mapping.raw(.inbox) == "inbox"`); `TaskNoteReaderTests.anInboxNoteIsReadWithItsStatus`; `TaskListFilterTests.theInboxListHoldsOnlyInboxTasks`; `DayMembershipTests.anInboxTaskIsNeverInADay` (`!membership.isInDay(makeTask("Idea", status: .inbox), skipped: [])`); `ConfigTests.theStatusesGroupStartsWithInbox`.
- [ ] **Step 2: Run** the five suites — FAIL.
- [ ] **Step 3: Implement**; update fixture-count expectations.
- [ ] **Step 4: Run** — PASS, then whole `SuperPooperTests`.
- [ ] **Step 5: Commit** `Inbox: a TaskNotes status of its own and the first list of Lists, never in the pool`

### Task 3.5: New Task intent: Inbox without a date, Soon with one

**Files:**
- Modify: `App/State/Tasks/NoteCommands.swift` (`createTask(named:)`), `Core/Intents/NewTaskIntent.swift` (description string only), `Localizable.xcstrings` (`intent.newTask.description`, `intent.newTask.created` may name Inbox/Soon: add `intent.newTask.createdInInbox`)
- Test: `Tests/App/NewTaskIntentTests.swift`

**Interfaces:**
- Consumes: `DateDetector`, `DateDetector.removing`.
- Produces: `NamedTaskCreation.created(String)` unchanged; the created note: no date → `status: .inbox`; date → `status: .thisWeek`, `due` = detected, name without the date words (unless that empties it). `NewTaskReply.created` gains `inInbox: Bool` so the dialog says where it went.

- [ ] **Step 1: Failing tests**

```swift
@Test func aNameWithoutADateGoesToTheInbox() async throws {
    let model = try #require(PreviewModel.make(appEvents: RecordingEvents())).model
    #expect(await model.createTask(named: "Купить молоко") == .created("Купить молоко"))
    #expect(model.task(named: "Купить молоко")?.status == .inbox)
}
@Test func aNameWithADateGoesToSoonOnThatDayWithoutTheDateWords() async throws {
    // SettableClock at Wed 2026-11-04 11:30
    #expect(await model.createTask(named: "Dentist tomorrow 18:20") == .created("Dentist"))
    let note = try #require(model.task(named: "Dentist"))
    #expect(note.status == .thisWeek && note.due == TaskDue(day: LocalDate("2026-11-05"), time: LocalTime("18:20")))
}
@Test func aNameThatIsOnlyADateStaysTheName() async throws {
    #expect(await model.createTask(named: "tomorrow") == .created("tomorrow"))
}
```
(Existing `aNamedTaskIsCreatedInSoonWithTheNewTaskPageDefaults` becomes the Inbox expectation.)

- [ ] **Step 2: Run** `…/NewTaskIntentTests` — FAIL.
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Stage gate**: D-entry «Распознавание даты и Inbox»; HANDBOOK §3 (date-grammar.json row), §5 (status `inbox`, owner adds it to TaskNotes settings himself); full UI suite.
- [ ] **Step 6: Commit** `New Task intent: without a date the task waits in the Inbox, with one it is in Soon on that day`

---

## Stage 4 — Backlog pages left of the pool

### Task 4.1: What Soon, Half year and Someday hold

**Files:**
- Modify: `Resources/Config/lists.json` (`"backlog": ["thisWeek", "halfYear", "someday"]` — list ids, nearest to the pool first), `Core/Config/TaskListsConfig.swift` (`let backlog: [String]`, validated: every id is a list with exactly one status)
- Create: `Domain/Lists/BacklogContents.swift`
- Test: `Tests/Domain/BacklogContentsTests.swift`, `Tests/Core/ConfigTests.swift`

**Interfaces:**
- Produces:
```swift
struct BacklogList: Hashable, Sendable { let id: String; let title: String; let icon: Icon; let status: TaskStatus }
extension TaskListsConfig { var backlogLists: [BacklogList] }
enum BacklogContents {
    /// Soon: this week's tasks not in `plan` (pool or timeline) of the shown day; other levels: their tasks. Name order.
    static func tasks(of list: BacklogList, in tasks: [TaskItem], plan: DayPlan) -> [TaskItem]
}
```
- `AppModel.backlogTasks(_ list: BacklogList, plan: DayPlan) -> [TaskItem]`.

- [ ] **Step 1: Failing tests**: `soonHoldsThisWeeksTasksTheDayDoesNotShow` (a this-week task in the pool is absent, one dated Friday is present on Wednesday's page), `halfYearAndSomedayHoldTheirLevel` (habits never), `ConfigTests.theBacklogNamesListsOfOneStatus`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `Backlog pages: Soon holds this week's tasks the shown day does not, Half year and Someday their levels`

### Task 4.2: The Tasks page strip and the sideways pull

**Files:**
- Create: `Features/Today/TasksPageStrip.swift`, `Domain/Gestures/PullArming.swift`
- Modify: `Features/Today/TodayPager.swift`, `Features/Common/PullToExtend.swift` (uses `PullArming`)
- Test: `Tests/Features/TasksPageStripTests.swift`, `Tests/Domain/PullArmingTests.swift`, `Tests/Features/TodayPagerTests.swift`

**Interfaces:**
- Produces:
```swift
enum TasksPage: Hashable { case backlog(String); case block(TodayBlockID); case today }
enum TasksPageStrip {
    /// Left to right: opened backlog pages (farthest first), then the layout's blocks when paged, else one `.today`.
    static func pages(layout: ScreenLayout, opened: Int, backlog: [BacklogList]) -> [TasksPage]
    static func homeIndex(layout: ScreenLayout, opened: Int) -> Int   // the pool's page
}
struct PullArming: Equatable { private(set) var isArmed = false
    mutating func update(pull: Double, threshold: Double) -> Bool    // true when it just armed (play pullArmed)
    mutating func release() -> Bool }                                 // true = run the action
// TodayPager:
private(set) var openedBacklog = 0                  // 0…backlog.count
private(set) var sidePull: CGFloat = 0              // how far the first page is pulled right
func swipeChanged(_:containerWidth:pageCount:gestures:)   // at the first page a rightward drag pulls instead of moving
func swipeEnded(…, backlogCount: Int) -> Bool       // true when a backlog page opened (the screen turns to it)
func closeBacklog()                                 // back to pool/timeline, left pages forgotten
```
`page` keeps indexing the strip; opening a page inserts it at index 0 and keeps the shown page by shifting `page` by one before turning to 0.

- [ ] **Step 1: Failing tests**

```swift
@Test func pagedTodayHasTheBacklogLeftOfThePool() {
    #expect(TasksPageStrip.pages(layout: paged, opened: 2, backlog: lists) == [.backlog("halfYear"), .backlog("thisWeek"), .block(.pool), .block(.timeline)])
    #expect(TasksPageStrip.homeIndex(layout: paged, opened: 2) == 2)
}
@Test func otherLayoutsHaveTheBacklogLeftOfAllOfToday() {
    #expect(TasksPageStrip.pages(layout: stacked, opened: 1, backlog: lists) == [.backlog("thisWeek"), .today])
}
@Test func pullingTheFirstPageRightPastTheThresholdOpensTheNextList() {
    let pager = TodayPager()
    pager.swipeChanged(CGSize(width: 80, height: 0), containerWidth: 390, pageCount: 2, gestures: gestures)
    #expect(pager.sidePull == 80 && pager.page == 0)
    #expect(pager.swipeEnded(CGSize(width: 80, height: 0), predicted: .zero, containerWidth: 390, pageCount: 2,
                             gestures: gestures, duration: 0, backlogCount: 3))
    #expect(pager.openedBacklog == 1 && pager.page == 0)
}
@Test func aShortPullOpensNothingAndAllListsOpenedPullsNoMore() {
    // pull 30 → swipeEnded == false, openedBacklog == 0; with openedBacklog == 3 a pull of 80 → false, sidePull == 0
}
@Test func leavingTheTabForgetsTheLeftPages() { pager.closeBacklog(); #expect(pager.openedBacklog == 0 && pager.page == 0) }
@Test func pullArmingArmsOnceAndRunsOnRelease() {
    var arming = PullArming()
    #expect(arming.update(pull: 61, threshold: 60)); #expect(!arming.update(pull: 70, threshold: 60))
    #expect(arming.release()); #expect(!arming.release())
}
```

- [ ] **Step 2: Run** the three suites — FAIL. **Step 3: Implement** (threshold `rules.gestures.pullThreshold`, disarm under half of it as `PullToExtend` does now). **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `Today pages: pulling the pool right past its edge opens Soon, then Half year, then Someday`

### Task 4.3: Backlog pages on screen

**Files:**
- Create: `Features/Today/BacklogPage.swift`, `DesignSystem/Components/PullIndicator.swift`
- Modify: `Features/Today/TodayScreen.swift` (renders `TasksPageStrip` through a generalized `PagedStack`; principal title: `DayNavigation` on `.block`/`.today` pages, plain `Text(list.title)` on a backlog page; `.onChange(of: router.tab)` away and back → `pager.closeBacklog()`), `DesignSystem/Components/PagedStack.swift` (generic over a `Hashable` page id instead of `ScreenLayout.Slot`, peeks per page; the turn edge works for every neighbour), `DesignSystem/Components/ScreenLayoutView.swift`, `Features/Common/PullToExtend.swift` (draws `PullIndicator`)
- Test: `Tests/DesignSystem/PageStripTests.swift`; UI: `UITests/TodayUITests.swift`

**Interfaces:**
- Consumes: `TasksPageStrip`, `TodayPager.sidePull/openedBacklog`, `AppModel.backlogTasks`.
- Produces: `PullIndicator(icon: Icon, progress: Double, isArmed: Bool, axis: Axis)` — the one indicator for both pulls (scale and opacity rules moved from `PullToExtend`); the sideways one shows the next list's `icon` at the pool's leading edge. `BacklogPage(list:plan:handler:)` — `ScrollView` + `LazyVStack` of `PoolRow`s built from `DayItem(listed:)` (same plates, menus, swipes as the pool, `isToday: false` actions), empty text `lists.empty`.

- [ ] **Step 1: Failing test** `PageStripTests.everyPageOfAStripHasItsOwnPeek` (strip of 4: offsets of page 0…3 and the clamp at both ends).
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** `…/PageStripTests`, `…/TodayPagerTests` — PASS.
- [ ] **Step 5: UI tests**: `testPullingThePoolRightOpensSoonThenHalfYear` (drag from the pool's left part to the right ×2 → nav title "Soon", then the Half year title; the swipe left returns to Soon and the pool with the day title); `testAnotherTabForgetsTheLeftPages` (open Soon, tap Habits, tap Tasks → day title, no Soon page left of it). Run — PASS.
- [ ] **Step 6: Commit** `Today: Soon, Half year and Someday stand left of the pool with their own titles, forgotten when the tab changes`

### Task 4.4: Dragging between backlog pages, the pool and the timeline

**Files:**
- Create: `Features/Today/BacklogDropDelegate.swift`
- Modify: `Features/Today/TaskDragState.swift` (`Source.backlog(String)`; `turn(_ page: TasksPage)` replaces `turn(_ block:)`), `Features/Today/PoolBlock.swift` (drop from a backlog page on any shown day), `Features/Today/TimelineBlock.swift`, `App/State/Day/DayCommands.swift`, `App/State/AppModel+Menus.swift`/`AppModel+Tasks.swift` (intents)
- Test: `Tests/App/BacklogMoveTests.swift`, `Tests/Features/TaskDragStateTests.swift`; UI: `UITests/TodayUITests.swift`

**Interfaces:**
- Produces (`DayCommands`):
```swift
/// Dropped on a backlog page: its status (`thisWeek`, `halfYear`, `someday`). From today's pool to Soon = Not today;
/// from another day's pool to Soon the due date goes.
func moveToBacklog(_ name: String, list: BacklogList, from day: LocalDate?) async
/// From a backlog page into the pool of `day`: this week; today = undated (a due on another day goes), another day =
/// due on that day without a time; `poolOrder` only today.
func bringFromBacklog(_ name: String, to day: LocalDate, poolOrder: [String]?) async
```
Timeline drops from a backlog page go through `schedule(_:slot:at:)` plus `.status(.thisWeek)` (today only, as other timeline drops). Every drop plays `Haptics.play(.move)`/`.drop` as now; the faint copy is round 3's `dropGhost`.

- [ ] **Step 1: Failing tests**

```swift
@Test func aPoolTaskDroppedOnSoonIsNotToday() async throws { /* today → in postponed, status stays thisWeek */ }
@Test func aTaskDroppedOnSomedayGetsThatStatus() async throws { #expect(model.task(named: "Купить молоко")?.status == .someday) }
@Test func aSomedayTaskDroppedInTodaysPoolIsThisWeekAtThatSpot() async throws {
    #expect(note.status == .thisWeek && note.due == nil); #expect(model.parts.day.dayState.manualOrder?.firstIndex(of: "Выучить испанский") == 1)
}
@Test func aTaskDroppedInAnotherDaysPoolIsDatedThatDay() async throws { #expect(note.due == TaskDue(day: friday)) }
@Test func aDragOverAPageEdgeAsksForThatPage() { drag.turn(.backlog("thisWeek")); #expect(drag.turnRequest == .backlog("thisWeek")) }
```

- [ ] **Step 2: Run** `…/BacklogMoveTests`, `…/TaskDragStateTests` — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: UI test** `testAPoolRowDraggedOntoSoonLeavesTheDay` (open Soon, swipe back to the pool, drag "Купить молоко" onto the Soon edge then into the page → the row is in Soon, not in the pool). PASS.
- [ ] **Step 6: Stage gate**: D-entry «Листы слева от пула»; HANDBOOK §4.3 (pages, drags, reset); full UI suite.
- [ ] **Step 7: Commit** `Drag: tasks move between Soon, Half year, Someday, the pool and the timeline, taking that list's status or the page's day`

---

## Stage 5 — Pool sections; the day routine goes

### Task 5.1: Remove the day routine everywhere

**Files:**
- Modify: `Domain/Model/HabitTimeOfDay.swift` (`morning`, `evening` only), `Domain/Day/HabitRoutines.swift`, `Core/Storage/AppSettings.swift` (`dayRoutine` gone), `Core/Storage/SettingsMigration.swift` (drop `habits.dayRoutine` when reading, both files), `Resources/Config/defaults.json`, `Resources/Config/field-mapping.json` (`timesOfDay.day` gone), `Data/TaskNotes/FieldMapping.swift` (`time_of_day: day` reads as none), `Domain/Day/ReviewGroups.swift`, `Domain/Day/PoolSortCriterion.swift` + `Resources/Config/sort.json` + `Domain/Day/PoolSorter.swift` + `Domain/Day/DayRules.swift` (`morningRoutine`, `habitTimeOfDay` and `partOfDay` removed — Decision: sections take over Morning-first/Evening-last, and with no day routine both criteria are no-ops inside a section), `Features/Habits/RoutinesScreen.swift`, `Features/Habits/HabitOptionsSection.swift`, `Localizable.xcstrings` (`routines.day`, `habitPage.timeOfDay.day`), tests that use `.day`
- Test: `Tests/Core/SettingsMigrationTests.swift`, `Tests/Data/FieldMappingTests.swift`, `Tests/Domain/HabitsInTodayTests.swift`, `Tests/Domain/PoolSorterTests.swift`, `Tests/Domain/ReviewGroupsTests.swift`

- [ ] **Step 1: Failing tests**: `SettingsMigrationTests.theDayRoutineIsDroppedWhenRead` (settings JSON with `habits.dayRoutine` → decoded settings, re-encoded, has no `dayRoutine`); `FieldMappingTests.aDayTimeOfDayReadsAsNoRoutine` (`mapping.timeOfDay(fromRaw: "day") == nil`); `HabitsInTodayTests` routines use only morning/evening; `PoolSorterTests` expectations without the two criteria; `ConfigTests.sortJsonNamesOnlyKnownCriteria`.
- [ ] **Step 2: Run** the suites — FAIL. **Step 3: Implement** (grep `\.day\b` near routines, `dayRoutine`, `partOfDay`). **Step 4: Run** whole `SuperPooperTests` — PASS.
- [ ] **Step 5: Commit** `Routines: only Morning and Evening are left; the day routine is gone from settings, notes, sorting and texts`

### Task 5.2: Sections as data and their store

**Files:**
- Create: `Domain/Day/Sections/DaySections.swift`, `Domain/Day/Sections/PoolSectionDefinition.swift`, `Core/Storage/DaySectionStore.swift`
- Modify: `Resources/Config/rules.json` (`pool.defaultSections`), `Core/Config/RulesConfig.swift` (+ validation: ids unique, exactly one `catchesRest`, each `routine` at most once)
- Test: `Tests/Domain/DaySectionsTests.swift`, `Tests/Core/DaySectionStoreTests.swift`, `Tests/Core/ConfigTests.swift`

**Interfaces:**
- Produces:
```swift
struct PoolSectionDefinition: Codable, Hashable, Sendable { let id: String; let title: String; var routine: HabitTimeOfDay?; var catchesRest = false }
// rules.json: [{"id":"morning","title":"section.morning","routine":"morning"},{"id":"day","title":"section.day","catchesRest":true},{"id":"evening","title":"section.evening","routine":"evening"}]
struct DaySection: Codable, Hashable, Sendable { let id: String; var title: String?  /* nil = the definition's */ ; var isCustom: Bool }
struct DayWorm: Codable, Hashable, Sendable { let id: String; var members: [String] }
struct DaySections: Codable, Equatable, Sendable {
    let day: LocalDate
    var order: [DaySection]
    var membership: [String: String]      // note name → section id
    var worms: [DayWorm] = []
    static func defaults(on day: LocalDate, definitions: [PoolSectionDefinition]) -> DaySections
    func renaming(from old: String, to new: String) -> DaySections
    func removing(_ names: [String]) -> DaySections
}
protocol DaySectionStorage: Sendable {
    func snapshot(for day: LocalDate) -> DaySections?
    func save(_ sections: DaySections) throws
    func dropDays(before day: LocalDate) throws
}
struct JSONDaySectionStore: DaySectionStorage { static let fileName = "day-sections.json"; let store: JSONFileStore }
```
Decision: snapshots are kept per day in one file next to `day-state.json`; past days are dropped when the day rolls.

- [ ] **Step 1: Failing tests**: `DaySectionsTests.aDayWithoutASnapshotHasTheThreeDefaults` (`order.map(\.id) == ["morning","day","evening"]`, `membership.isEmpty`); `renamingFollowsMembershipAndWorms`; `removingLeavesNoMemberAndAWormOfOneGoes`; `DaySectionStoreTests.eachDayKeepsItsOwnSnapshot` and `pastDaysAreDropped` (in a `VaultSandbox`/temp `JSONFileStore`); `ConfigTests.defaultSectionsHaveExactlyOneForTheRest`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `Sections: each day keeps its own sections and members in day-sections.json, Morning, Day and Evening by default`

### Task 5.3: Arranging the pool by sections

**Files:**
- Create: `Domain/Day/Sections/PoolArrangement.swift`
- Modify: `Domain/Day/DayPlan.swift` (`var sections: [PoolSectionContent] = []`; `pool` stays the flattened order), `Domain/Day/DayInputs.swift` (`var sections: DaySections?`), `Domain/Day/DayBuilder.swift`, `Core/Widgets/DayPlanning.swift` (takes `sections:`; widgets read the stored snapshot from the App Group), `App/State/Derived/DerivedStatePublisher.swift`, `App/State/Derived/PlanKey.swift`
- Test: `Tests/Domain/PoolArrangementTests.swift`, `Tests/Domain/FixtureDayPlanTests.swift`

**Interfaces:**
- Produces:
```swift
struct PoolSectionContent: Identifiable, Hashable, Sendable { let id: String; let title: String /* text key or custom title */; let isCustom: Bool; let items: [DayItem] }
enum PoolArrangement {
    /// Sections in their order; each holds its members in the pool's sort/manual order. Without a snapshot entry an
    /// item goes by its routine (`time_of_day` morning/evening) or to the section that catches the rest. Custom
    /// sections without items are left out; the default ones always show. Worm members stand together at the first
    /// member's place.
    static func arrange(_ pool: [DayItem], sections: DaySections, definitions: [PoolSectionDefinition]) -> [PoolSectionContent]
}
```

- [ ] **Step 1: Failing tests**

```swift
@Test func byDefaultRoutinesGoToMorningAndEveningTheRestToDay() {
    let content = PoolArrangement.arrange(pool, sections: .defaults(on: wednesday, definitions: defs), definitions: defs)
    #expect(content.map(\.id) == ["morning", "day", "evening"])
    #expect(content[0].items.map(\.id) == ["Утро — душ 🚿"] && content[2].items.map(\.id) == ["Стирка 🧺"])
}
@Test func anEmptyCustomSectionGoesButAnEmptyDefaultStays() { /* snapshot with custom "Errands" and no members, no morning items → ids == ["morning","day","evening"] */ }
@Test func theSnapshotOverridesTheRoutineForThatDayOnly() { /* membership["Стирка 🧺"] = "day" → in day; defaults(on: thursday) → in evening */ }
@Test func withinASectionThePoolOrderIsKept() { /* day items keep the relative order of `pool` */ }
@Test func theNextDayStartsFromTheDefaultsAndCustomMembersFallIntoDay() { /* yesterday's custom member, open today, no snapshot → in "day" */ }
```

- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** `…/PoolArrangementTests` and whole `SuperPooperTests` — PASS.
- [ ] **Step 5: Commit** `Pool: sorted by its sections first, then by sort.json and the manual order inside each`

### Task 5.4: `DaySectionsController` and the commands

**Files:**
- Create: `App/State/Day/DaySectionsController.swift`
- Modify: `App/State/AppParts.swift`, `App/AppContainer.swift`, `Debug/PreviewModel.swift`, `App/State/Day/DayCommands.swift`, `App/State/Tasks/NoteCommands.swift` (rename/delete follow), `App/State/Tasks/UndoController.swift` (`Step.sections: DaySections?` restored), `App/State/AppModel.swift` (`sections(on day:)` read-only)
- Test: `Tests/App/DaySectionsControllerTests.swift`

**Interfaces:**
- Produces:
```swift
@MainActor @Observable final class DaySectionsController {
    init(store: DaySectionStorage, day: DayStateController, definitions: [PoolSectionDefinition])
    func snapshot(on day: LocalDate) -> DaySections          // stored or defaults
    func update(on day: LocalDate, _ change: (inout DaySections) -> Void)
    func followRename(from old: String, to new: String)
    func forget(_ names: [String])
    func rollDayIfNeeded()                                    // drops past days
}
// DayCommands:
func moveTask(_ name: String, toSection id: String, poolOrder: [String], on day: LocalDate) async
func moveSection(_ id: String, order: [String], on day: LocalDate) async
```

- [ ] **Step 1: Failing tests**: `aTaskMovedToEveningIsThereOnlyThatDay`; `aRoutineMovedToDayDoesNotChangeTheRoutine` (`settings.habits.eveningRoutine` and the note's `time_of_day` unchanged); `aSectionMovedKeepsItsMembers`; `aRenameFollowsAndADeleteLeaves` (Review Focus 5).
- [ ] **Step 2: Run** `…/DaySectionsControllerTests` — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `Sections: a task or a whole section moved stays so for that day, renames follow and deletes leave`

### Task 5.5: Sections in the pool: one header, dragging tasks and sections

**Files:**
- Create: `DesignSystem/Components/SectionHeader.swift`, `Domain/Day/Sections/SectionDropOrder.swift`
- Modify: `Features/Today/PoolBlock.swift` (one `SectionHeader` per `plan.sections`, rows under it), `Domain/Day/PoolDropOrder.swift` (rows carry their section; returns the section above the drop spot), `Features/Today/TaskDragState.swift` (`Source.section(String)`; `sectionOrder` while dragging a header), `DesignSystem/Components/ListGroupHeader.swift` and `PlateSection.swift` header text drawn by `SectionHeader` (one look in the whole app), `tokens.json` (`font.sectionHeader`, `color.sectionHeader` = secondary text, `space.sectionHeaderInset` = a little right of the plates' left edge), `TokenKeys.swift`, `Localizable.xcstrings` (`section.morning` "Morning", `section.day` "Day", `section.evening` "Evening")
- Test: `Tests/Domain/PoolDropOrderTests.swift`, `Tests/Domain/SectionDropOrderTests.swift`; UI: `UITests/TodayUITests.swift`

**Interfaces:**
- Produces: `struct SectionDropOrder.Header: Equatable { let id: String; let midY: Double }`; `PoolDropOrder.Row { id; midY; section: String }` and `static func drop(rows: [Row], headers: [SectionDropOrder.Header], dragged: String, at y: Double) -> (order: [String], section: String)`; `SectionDropOrder.order(headers: [Header], dragged: String, at y: Double) -> [String]` — below another header's middle = after that whole section, above = before it; a header drag only targets the pool (the timeline and backlog delegates refuse `.section`).

- [ ] **Step 1: Failing tests**: `PoolDropOrderTests.aTaskDroppedUnderEveningsHeaderJoinsEvening`; `SectionDropOrderTests.belowAHeaderGoesAfterThatSectionAboveBeforeIt`; `SectionDropOrderTests.theTimelineRefusesASection` (`TimelineDropDelegate.validateDrop` false for `.section` via a `TaskDragState` set up with `beginSection`).
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: UI test** `testATaskDraggedUnderEveningStaysThere` (drag "Купить молоко" below the "Evening" header → it is the first row under it after the drop and after a relaunch with the same day). PASS.
- [ ] **Step 6: Stage gate**: D-entry «Секции пула; дневной рутины больше нет»; HANDBOOK §4.5 (sorting), §4.7 (routines), §3 (`pool.defaultSections`, tokens), §1 table (`day-sections.json`); full UI suite.
- [ ] **Step 7: Commit** `Pool: Morning, Day and Evening sections with one grey header, tasks and whole sections dragged between them`

---

## Stage 6 — Select and batch actions

### Task 6.1: Actions and batch availability

**Files:**
- Modify: `Domain/Actions/ActionID.swift` (`select`, `highPriority`, `worm`, `unworm`, `newSection`), `Resources/Config/actions.json` (definitions with icons `checkmark.circle`, `exclamationmark.triangle`, `link`… from the owner's look; menu `selection`: `"actions": ["done", "delete"], "more": ["notToday", "highPriority", "worm", "unworm", "newSection"]`; `taskContext`/`habitContext` `more` += `select`, `unworm`), `Core/Config/ActionRegistry.swift` (`ActionMenu.selection`), `Localizable.xcstrings` (`action.select` "Select", `action.highPriority` "High priority", `action.worm` "Worm", `action.unworm` "Unworm", `action.newSection` "New section")
- Create: `Domain/Actions/BatchAvailability.swift`
- Test: `Tests/Domain/BatchAvailabilityTests.swift`, `Tests/Domain/ActionAvailabilityTests.swift`, `Tests/Core/ConfigTests.swift`

**Interfaces:**
- Produces:
```swift
struct BatchAvailability: Sendable {
    let single: ActionAvailability
    let worms: [DayWorm]
    /// An action is offered when at least one selected item can take it; Worm needs two open items not all in one worm;
    /// Unworm needs one selected item in a worm; New section needs one item.
    func isAvailable(_ action: ActionID, for items: [DayItem]) -> Bool
    func entries(_ menu: MenuDefinition, for items: [DayItem]) -> (frequent: [ActionID], more: [ActionID])
}
```
`ActionAvailability.isAvailable(.unworm, …)` needs the item's worm: add `var worms: [DayWorm] = []` to `ActionAvailability`.

- [ ] **Step 1: Failing tests**: `oneDoneItemAmongOpenOnesStillOffersDone`; `wormNeedsTwoOpenItems`; `unwormOnlyForAWormMember`; `notTodayOnlyOnToday` (`isToday: false` → false); `ConfigTests.theSelectionMenuNamesKnownActions`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `Select: its actions and when each is offered for the selected tasks come from actions.json`

### Task 6.2: Batch actions in the model with one Undo

**Files:**
- Modify: `App/State/AppModel+Tasks.swift` (`performOfferingUndo(_ action: ActionDefinition, on names: [String], day: LocalDate?)`), `App/State/Tasks/UndoController.swift` (`begin(_:on names: [String])`, `Step.names`, `UndoOffer.names`), `App/Banners/BannerPresenter.swift` (several names: count text `banner.undo.many` with the action's title, no names joined in a line), `Localizable.xcstrings`
- Test: `Tests/App/UndoTests.swift`, `Tests/App/BatchActionTests.swift`, `Tests/App/BannerPresenterTests.swift`

**Interfaces:**
- Produces: batch rules — `done` marks each (habits: today's Done), `delete` trashes each (cascade as single), `notToday` each, `highPriority` sets true on all unless all are already high (then false); one Undo step covers every note and today's day state and sections snapshot.

- [ ] **Step 1: Failing tests**: `BatchActionTests.highPriorityTurnsOnForAllUnlessAllAreHigh`; `deleteTakesEverySelectedNote`; `UndoTests.undoingABatchDeleteBringsBackSectionsAndWorms` (Review Focus 5); `BannerPresenterTests.aBatchUndoBannerCountsTheNotes`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `Select: one action for all selected tasks, one Undo in the banner for all of them`

### Task 6.3: Worm

**Files:**
- Modify: `App/State/Day/DayCommands.swift` (`worm(_ names: [String], on day: LocalDate)`, `unworm(_ names: [String], on day: LocalDate)`), `Domain/Day/Sections/PoolArrangement.swift` (members together, all in the first member's section by shown order), `Domain/Day/PoolSegments.swift` (`make(_ pool:, worms:)` — a worm is one segment, shared plate like a routine), `DesignSystem/Components/PoolSegmentView.swift` (`isRoutine` → `isShared`), `Features/Today/PoolBlock.swift` (a member's drag drags the whole worm: `Source.worm(String)`), `App/State/AppModel+Tasks.swift` (`unworm` from the context menu)
- Test: `Tests/Domain/PoolSegmentsTests.swift`, `Tests/App/WormTests.swift`

**Interfaces:**
- Decision: a worm lives in the shown day's snapshot (any day), is visual only (no TaskNotes writes, no chains), is never split by sorting, and a worm left with one member is removed. Routine plates keep dragging row by row.

- [ ] **Step 1: Failing tests**: `PoolSegmentsTests.aWormIsOneSharedPlate`; `WormTests.wormedTasksStandTogetherInTheFirstOnesSection`; `aDoneMemberStaysInItsWorm` (decision: done members stay in the plate till the day ends); `unwormingOneOfTwoEndsTheWorm`; `nothingIsWrittenToNotes` (store write count unchanged).
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `Worm: selected tasks share one plate for that day, dragged as one, undone with Unworm`

### Task 6.4: New section

**Files:**
- Modify: `App/State/Day/DayCommands.swift` (`newSection(titled title: String, with names: [String], on day: LocalDate) -> String?` — nil for a blank title; the section is inserted after the section of the first selected task), `Localizable.xcstrings` (`section.new.title`, `section.new.placeholder`, `section.new.create`)
- Test: `Tests/App/NewSectionTests.swift`

- [ ] **Step 1: Failing tests**: `aNewSectionTakesTheSelectedTasksAndStandsAfterTheFirstOnesSection`; `aBlankTitleMakesNothing`; `itIsGoneWhenItsLastTaskLeaves`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `New section: a titled section of that day takes the selected tasks`

### Task 6.5: Select mode on screen

**Files:**
- Create: `Features/Today/PoolSelection.swift`, `Features/Today/SelectionToolbar.swift`
- Modify: `Features/Today/TodayScreen.swift` (while selecting: leading Cancel, trailing Done and Delete + "…" `Menu` with the `more` entries; the New section alert with a `TextField`), `Features/Today/PoolBlock.swift`, `Features/Today/PoolRowContent.swift` (a leading system `Image(systemName:)` from `icons.selectOn`/`selectOff` — `checkmark.circle.fill`/`circle` — in the accent color; tap toggles; drags, swipes, menus off), `Features/Today/TaskActionHandler.swift` (`.select` starts the mode with that row selected), `icons.json`, `IconSet.swift`
- UI: `UITests/SelectUITests.swift`

**Interfaces:**
- Produces: `@MainActor @Observable final class PoolSelection { private(set) var isOn = false; private(set) var names: Set<String> = []; func start(with name: String); func toggle(_ name: String); func end() }`.
- Decision (Уточнения): the pool stays the existing `ScrollView` + `LazyVStack` (a `List` would lose the shared routine/worm plates and the pool's own drop gaps across pages); selection is drawn with system symbols only and this is said in the stage report.

- [ ] **Step 1: UI tests**: `testSelectThenWormMakesOnePlate` (long press "Купить молоко" → Select → tap "Позвонить в банк" → "…" → Worm → both rows inside one plate element `pool.worm`); `testSelectDeleteOffersUndo` (select two → Delete → banner with Undo → Undo → both back); `testCancelLeavesSelect` (the day title and the Lists button are back). Run — FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run** `SelectUITests` — PASS.
- [ ] **Step 4: Stage gate**: D-entry «Select, Worm, New section»; HANDBOOK §3 (`selection` menu), §4.3; full UI suite.
- [ ] **Step 5: Commit** `Select: tasks picked with system circles, Done and Delete on the bar, Not today, High priority, Worm and New section under "…"`

---

## Stage 7 — Dragging "+" and holding on the timeline

### Task 7.1: One drag state for the whole app, and a new item as a dragged thing

**Files:**
- Modify: `Features/Today/TaskDragState.swift` (`Source.newItem`; `beginNewItem() -> NSItemProvider`; `draggedID: String?` = the item's id or `TaskDragState.newItemGap`), `App/RootView.swift` (owns `@State var taskDrag = TaskDragState()` and puts it in the environment), `Features/Today/TodayScreen.swift` (reads it from the environment)
- Test: `Tests/Features/TaskDragStateTests.swift`

- [ ] **Step 1: Failing tests**: `aNewItemDragHasNoNoteButAGapInThePool` (`drag.beginNewItem(); drag.hover(poolOrder: ["A", TaskDragState.newItemGap, "B"])`, `#expect(drag.isGap(TaskDragState.newItemGap) && drag.item == nil && drag.source == .newItem)`); `endingANewItemDragClearsIt`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `Drag: one drag state for the app, and "+" can be what is dragged`

### Task 7.2: Where a "+" lands becomes the new task's date, time and pool spot

**Files:**
- Create: `Domain/Model/NewItemPlacement.swift`
- Modify: `Domain/Model/NewItemSeed.swift` (`placement`), `App/State/Tasks/NewItemPage.swift` (`init(seed:taskDraft:habitDraft:context:)` applies a timeline placement as `.due`), `App/State/Tasks/NoteCommands.swift` (after creating, a pool placement asks `DayCommands.place`), `App/State/Day/DayCommands.swift`
- Test: `Tests/App/NewItemPlacementTests.swift`

**Interfaces:**
- Produces:
```swift
enum NewItemPlacement: Hashable, Sendable {
    case timeline(day: LocalDate, time: LocalTime)            // time already on the drop step
    case pool(order: [String], section: String)              // order holds TaskDragState.newItemGap where it landed
}
// DayCommands:
func place(_ name: String, at placement: NewItemPlacement) async   // pool: the gap becomes `name` in today's manual order and its section
```

- [ ] **Step 1: Failing tests**: `aTimelinePlacementPresetsTheDraftsDayAndTime` (draft `due == TaskDue(day: friday, time: LocalTime("15:30"))`); `aPoolPlacementPutsTheNewTaskAtTheGapAndInItsSection` (manual order `["A","New","B"]`, membership `New → evening`); `aHabitFromATimelineDropGetsThatTimeAsItsReminder` (decision: switched to Habit, the dropped time becomes `reminderTimes == [LocalTime("15:30")]`).
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `New item: a "+" dropped on the timeline sets the day and time, dropped in the pool the spot and the section`

### Task 7.3: "+" lifts and drops; holding the empty timeline does the same

**Files:**
- Modify: `App/NewItemButton.swift` (`.onDrag { drag.beginNewItem() }` with the same lift (`plateLift`) and haptic; only on the Tasks tab), `Features/Today/TaskDragState.swift` (`TimelineDropDelegate`/`PoolDropDelegate` accept `.newItem`: timeline on any shown day, pool on today; landing → `router.openNewItem(NewItemSeed(kind: .task, placement:))`), `Features/Today/PoolBlock.swift` (gap ghost = an empty plate in `opacity.dropGhost`), `Features/Today/TimelineBlock.swift` (a long press on empty timeline space → the same placement at the pressed moment; events and blocks keep their own long press), `rules.json` (`gestures.timelineHoldSeconds` if the system default is not used)
- Test: `Tests/Domain/TimelineOpeningTests.swift` or new `Tests/Domain/TimelineHoldTests.swift`; UI: `UITests/NewItemDragUITests.swift`

**Interfaces:**
- Produces: `TaskScheduling.placement(atOffset:windowStart:hourHeight:stepMinutes:calendar:day:) -> NewItemPlacement` — the one rule for drop and hold.

- [ ] **Step 1: Failing test** `TimelineHoldTests.aHoldAndADropAtTheSameSpotGiveTheSamePlacement`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: UI tests**: `testPlusDroppedOnTheTimelineOpensATaskAtThatTime` (drag `tabBar.newItem` to the 15:00 line → page opens, chip shows Today, time row 15:00); `testPlusDroppedBetweenPoolRowsSavesThere` (drop between row 1 and 2, type "Inserted", Return, Back → "Inserted" is the second row); `testPlusDroppedElsewhereDoesNothing`; `testHoldingTheEmptyTimelineOpensATask`. PASS.
- [ ] **Step 6: Stage gate**: D-entry «Перетаскивание "+"» (same drag-and-drop as the pool, gap ghost, hold on the timeline .42611); HANDBOOK §4.3; full UI suite.
- [ ] **Step 7: Commit** `"+": dragged onto the timeline or between pool rows it opens a new task there; holding the empty timeline does the same`

---

## Stage 8 — Repeatable subtasks

### Task 8.1: A habit's or repeatable task's subtask is created repeatable

**Files:**
- Modify: `Domain/Model/NoteDraft.swift` (`static func repeatableSubtask(of parent: TaskItem) -> NoteDraft` = `.habit` status, `.addProject(parent.name)`, `.repeatable(true)`, `.recurrence(parent.recurrence)`, `.showInToday(parent.habit.showInToday)`), `App/State/Tasks/NoteCommands.swift` (`createSubtask` picks by `parent.isHabit`)
- Test: `Tests/App/RepeatableSubtaskTests.swift`, `Tests/Data/CreateTaskTests.swift`

- [ ] **Step 1: Failing tests**: `aHabitsSubtaskIsARepeatableTaskWithTheParentsRule` (note: `isHabit`, `habit.repeatable`, `projects == ["Утро — зарядка 🤸"]`, `recurrence == parent.recurrence`); `aTasksSubtaskIsStillAOneOffTask`; `CreateTaskTests.aRepeatableSubtaskIsWrittenAsTaskNotesWrites` (frontmatter: `status: habit`, `recurrence`, `projects` link, `repeatable` inside `fromSuperPooperApp`).
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `Subtasks: a habit's or a repeatable task's subtask is repeatable too, with its parent's rule`

### Task 8.2: Shown when the parent is, marked per day, hidden from the Habits list

**Files:**
- Create: `Domain/Day/RepeatableSubtasks.swift`
- Modify: `Domain/Day/Building/DayMembership.swift` (a repeatable subtask is in a day exactly when its parent is), `Domain/Habits/HabitGroups.swift` (repeatable subtasks are not rows of Habits; they show on the parent's page under Subtasks), `Domain/Notifications/NotificationPlanner.swift` (no own notification unless it has its own reminder times — decision)
- Test: `Tests/Domain/RepeatableSubtasksTests.swift`, `Tests/Domain/HabitGroupsTests.swift`

**Interfaces:**
- Produces: `enum RepeatableSubtasks { static func parent(of task: TaskItem, in tasks: [TaskItem]) -> TaskItem?; static func isRepeatableSubtask(_ task: TaskItem, in tasks: [TaskItem]) -> Bool }`; `DayMembership.init(occurrence:context:parents: [String: TaskItem])`.

- [ ] **Step 1: Failing tests**: `itIsInTheDaysTheParentIs` (parent every Mon/Wed: in on Wednesday, not Tuesday, whatever its own rule); `skippingTheParentLeavesItButItCanBeSkippedAlone`; `doneTodayIsOnlyToday` (mark on Wednesday, open on Friday); `HabitGroupsTests.repeatableSubtasksAreNotHabitRows`; `deletingTheParentTakesIt` (via `SubtaskCascade.deletion`, already true — pin it).
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `Repeatable subtasks: in the day whenever their parent is, Done and Skip today for each day, not rows of Habits`

### Task 8.3: The parent's new rule reaches its subtasks

**Files:**
- Modify: `App/State/Tasks/NoteWriter.swift` (after a `.recurrence` edit of a habit, the same rule is written to its repeatable subtasks), `Domain/Day/RepeatableSubtasks.swift` (`static func followingRule(of parent: TaskItem, in tasks: [TaskItem]) -> [(name: String, edits: [TaskEdit])]`)
- Test: `Tests/Domain/RepeatableSubtasksTests.swift`, `Tests/App/RepeatableSubtaskTests.swift`

- [ ] **Step 1: Failing tests**: `aNewParentRuleIsCopiedToEachRepeatableSubtask`; `aOneOffSubtaskIsLeftAlone`; `aParentWithoutARuleLeavesTheSubtasksRuleAlone` (a parent's rule set to nil writes nothing to subtasks). Page edits offer no Undo (Undo is for menu and swipe actions), so nothing changes there.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: Stage gate**: D-entry «Повторяющиеся подзадачи» (old one-off subtasks of habits are not migrated); HANDBOOK §4.7, §5; full UI suite.
- [ ] **Step 6: Commit** `Repeatable subtasks: a change of the parent's rule is written to them too`

---

## Stage 9 — Time zones

### Task 9.1: No zone means the phone's clock; a zone means the moment — pinned by tests

**Files:**
- Test: `Tests/Domain/TimeZoneMatrixTests.swift`, `Tests/App/TimeZoneChangeTests.swift`, `Tests/Domain/NotificationPlannerTests.swift`
- Modify (only if a test fails): `Domain/Model/ZonedTimes.swift`, `Data/Notifications/NotificationTrigger.swift`, `App/State/Sync/SyncService.swift`

- [ ] **Step 1: Write the tests**

```swift
@Test func aHabitWithoutAZoneRingsAtNineWhereverThePhoneIs() async throws {
    // habit reminder 09:00, no time_zone; calendar Australia/Sydney → Europe/Istanbul (SettableClock + calendar source)
    #expect(planned.first?.fire == moment("2026-11-05 09:00", in: "Europe/Istanbul"))
}
@Test func aTaskWithAZoneRingsAtItsMomentAndStandsThereOnTheTimeline() async throws {
    // due 2026-11-05 09:00, time_zone Australia/Sydney; phone in Istanbul → timeline slot at 01:00 Istanbul
}
@Test func aZoneChangePlansTheNotificationsAgain() async throws { /* existing notificationsArePlannedAgainInTheNewZone extended to habits */ }
```

- [ ] **Step 2: Run** the three suites. Expected: PASS if the existing `ZonedTimes` / `NotificationTrigger` already do it (the spec says they exist); any FAIL is a bug — fix the cause, keep the test.
- [ ] **Step 3: Commit** `Time zones: without a zone times follow the phone's clock, with one they are fixed moments, pinned by tests`

### Task 9.2: "None" everywhere a zone is picked

**Files:**
- Modify: `Features/TaskPage/TimeZoneRow.swift` (habit page row, `taskPage.timeZone.none`), `Features/TaskPage/DuePickerSheet.swift`, `Localizable.xcstrings` (`taskPage.timeZone.phone` → removed, `info.taskPage.timeZone` reworded: None = the phone's clock)
- UI: `UITests/TaskPageUITests.swift`

- [ ] **Step 1: UI test** `testTimeZoneIsNoneUntilChosen` (new task → date chip → time on → Time zone row reads "None" → pick "Tokyo" → row reads "Asia/Tokyo" name; habit page with a reminder shows "None"). Run — FAIL.
- [ ] **Step 2: Implement.** **Step 3: Run** — PASS.
- [ ] **Step 4: Stage gate**: D-entry «Часовой пояс: None по умолчанию» (field `time_zone` in `fromSuperPooperApp`, as already written by the adapter); HANDBOOK §5; full UI suite + vault check.
- [ ] **Step 5: Commit** `Time zone: None until a zone is chosen, on the date sheet and on a habit's page`

---

## Self-review notes

- Spec coverage: §1 → 1.1–1.3, 7.1–7.3; §2 → 1.3; §3 → 2.1–2.4; §4 → 3.1–3.3, 3.5; §5 → 3.4–3.5; §6 → 4.1–4.4; §7 → 5.1–5.5; §8 → 6.1–6.5 (the menu divider itself is round 3); §9 → 8.1–8.3; §10 → 2.4, 9.1–9.2; Уточнения: sections per day and routines unchanged (5.3–5.4), Select on the existing pool (6.5), left pages in every layout (4.2–4.3), Worm visual and per shown day (6.3), repeatable subtasks follow the parent (8.2–8.3), Inbox status (3.4). The home-screen quick action keeps opening the page (`new-task` link, 1.1).
- Builder decisions taken here: reserved search-role tab for the "+" room (1.2); kind switch keeps both drafts (2.1); chips shared with the task page (2.3); weekday = next such day after today, `D.M` day-first, yearless date = next occurrence (3.2); Inbox first in `TaskStatus.open` and in Lists (3.4); pool → Soon = Not today (4.4); `morningRoutine`/`habitTimeOfDay` criteria removed (5.1); default membership by `time_of_day` incl. tasks put in a part by the morning review (5.3); done worm members stay in the worm (6.3); habit created from a timeline drop gets that time as its reminder (7.2); repeatable subtasks hidden from the Habits list, no own notification without own times (8.2).
