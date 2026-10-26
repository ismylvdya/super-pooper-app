#!/bin/bash
# Проверяет файлы тестового vault в симуляторе после UI-тестов (scripts/sim.sh load-vault → UI-тесты → этот скрипт).
set -uo pipefail
cd "$(dirname "$0")/.."
UDID="$(scripts/sim.sh udid)"
BUNDLE_ID="$(grep -E '^SP_BUNDLE_ID' Config/Shared.xcconfig | sed 's/.*= *//')"
VAULT="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)/Documents/TestVault"
TASKS="$VAULT/TaskNotes/Tasks"
TODAY="$(date +%Y-%m-%d)"
FAILED=0
check() { if eval "$2"; then echo "OK    $1"; else echo "FAIL  $1"; FAILED=1; fi; }

check "Habits: Done → complete_instances has today"  "grep -A20 '^complete_instances:' \"$TASKS/Медитация 🧘.md\" | grep -q \"$TODAY\""
check "long press Done → status done + completed_date" "grep -q '^status: done' \"$TASKS/Оплатить интернет.md\" && grep -q \"^completed_date: $TODAY\" \"$TASKS/Оплатить интернет.md\""
check "long press Partially → partial_instances"     "grep -A20 '^partial_instances:' \"$TASKS/Выпить воды 💧.md\" | grep -q \"$TODAY\""
check "task page High → priority: high"              "grep -q '^priority: high' \"$TASKS/Распечатать вопросы.md\""
check "rename → new file, old gone"                  "[ -f \"$TASKS/Записать идеи 2.md\" ] && [ ! -f \"$TASKS/Записать идеи.md\" ]"
check "archive → status: archived"                   "grep -q '^status: archived' \"$TASKS/Купить батарейки 🔋.md\""
check "delete → moved to .trash"                     "[ -f \"$VAULT/.trash/Посмотреть сериал 🍿.md\" ] && [ ! -f \"$TASKS/Посмотреть сериал 🍿.md\" ]"
check "picker → previous_task link written"          "grep -qF 'uid: \"[[Найти отвёртку]]\"' \"$TASKS/Помыть окна.md\""
check "event picker → previous_event written"        "grep -q '^previous_event: \".*|Call with dad|' \"$TASKS/Сходить к стоматологу.md\""
check "plus in Habits → new habit, in Today"         "grep -q '^status: habit' \"$TASKS/Читать 20 минут.md\" && grep -qF '\"show_in_today\":true' \"$TASKS/Читать 20 минут.md\" && grep -q '^recurrence: ' \"$TASKS/Читать 20 минут.md\""
check "plus in review → new this_week note"           "grep -q '^status: this_week' \"$TASKS/Позвонить врачу.md\""
check "subtask dragged → its place in subtask_order"  "grep -qF '\"subtask_order\":' \"$TASKS/Шаг один.md\""
check "unknown keys and body untouched"              "grep -q '^  nested: значение' \"$TASKS/Длинная заметка с незнакомыми ключами.md\""
exit $FAILED
