//
//  AGENTS.md
//  CalSync
//
//  Created by Тумашев Дмитрий Сергеевич on 27.01.2026.
//

# AGENTS.md — Guidelines for coding agents (Codex / AI) working on this repo

This document defines **how an agent should behave** while implementing tasks in this project.
Follow it strictly to keep the codebase consistent, testable, and reviewable.

---

## 1) Agent role and boundaries

### Your role
- Implement the requested step **exactly as described**, with the smallest safe set of changes.
- Keep the project **always buildable** after each step.
- Provide a clear summary of what changed and how to verify.

### Hard boundaries (do not violate)
- **No scope creep:** do not implement future steps early.
- **No “big bang” refactors:** small, incremental, reversible changes.
- **No direct EventKit usage in SwiftUI views.** All EventKit access goes through a gateway/service layer.
- **No storing markers inside events** (notes/url/title/etc.). Mapping is local-only (DB).
- **No network features** unless explicitly requested.
- **No unreviewed dependencies:** do not add third-party libraries unless asked. If absolutely needed, propose first.

---

## 2) Workflow rules (how to work)

### Atomic steps
For each requested task:
1. Implement the change set.
2. Ensure it **compiles**.
3. Run relevant tests (unit and/or UI).
4. If tests are missing, **add them** for the logic you introduced.
5. Provide a short report:
   - files changed
   - how to run/verify
   - any follow-ups required by the next step

### Verification discipline
- Prefer running:
  - Unit tests: `AppTests`
  - UI tests: `AppUITests` (when relevant)
- If you introduce time-dependent logic, make it deterministic (inject a clock/date provider).

### When blocked
If something is ambiguous and blocks progress:
- Make a reasonable assumption **only if it’s low risk**, document it in the report.
- Otherwise, stop and ask for a clarification (one concise question), and do not guess.

---

## 3) Project architecture constraints

### Layering (must keep)
- **UI (SwiftUI)**: presentation only, no EventKit/CoreData direct calls.
- **Coordinator / AppShell**: window management, activation policy, status bar wiring.
- **SyncEngine (actor)**: all sync orchestration, scheduling, debouncing, single-flight.
- **EventKitGateway (protocol)**: EventKit access behind an interface for testability.
- **Persistence (Core Data)**: mapping and error history; in-memory mode for tests.

### Concurrency
- Sync engine must be an `actor` (single-flight by design).
- UI-facing state updates happen on `@MainActor`.
- Avoid deadlocks and nested sync calls; use structured concurrency.

### Error handling
- No `try!`, no force unwraps in production paths.
- Convert low-level errors into user-facing error messages in a consistent way.
- Persist only minimal error info (do not log event titles/notes unless explicitly required).

---

## 4) Coding standards

### Swift style
- Use Swift Concurrency (`async/await`) rather than callbacks where practical.
- Prefer value types (struct DTOs) for payloads.
- Avoid “god objects” and long methods; extract helpers.

### Naming
- Types: `UpperCamelCase`
- Methods/vars: `lowerCamelCase`
- Enums: cases in `lowerCamelCase`
- Use clear domain naming: `SyncReason`, `CalendarInfo`, `EventInfo`, `SyncedEventLink`.

### Logging
- Use `os.Logger` (not `print`) outside tests.
- Never log sensitive calendar content by default.

---

## 5) EventKit + macOS specifics

### Permissions
- Respect sandbox + Calendar entitlement requirements.
- Provide a clear “no permission” state in the app UI.
- Handle permission revocation gracefully (sync must stop and show error).

### Store change notifications
- Subscribe to EventKit store change notifications and **debounce** sync requests.
- Keep a fallback timer (15 minutes) as requested.

### Menu-bar app behavior
- Must support:
  - menu-bar icon + menu actions
  - open/activate window on click
  - hide Dock icon when window is closed (activation policy accessory)
- App must remain running when the window closes.

---

## 6) Persistence rules (Core Data)

### What is stored
- Mapping links between source and mirrored events.
- Minimal sync metadata (timestamps, hashes, counters).
- Recent errors (bounded list).

### What is NOT stored
- No full copies of event contents unless strictly necessary.
- No “marker strings” embedded in calendar events.

### Migration
- Enable lightweight migration.
- Keep entities stable; avoid frequent model churn.

---

## 7) Testing requirements

### Unit tests (mandatory for core logic)
- Use a `FakeEventKitGateway` for deterministic behavior.
- Use **in-memory Core Data** for repositories.
- Test:
  - create/update/delete flows
  - moved-out-of-window still updates
  - recurrence copied as separate single events
  - debounce + single-flight behavior
  - reset sync removes managed items only
  - identifier changes update mapping

### UI tests (minimal but stable)
- If menu-bar interactions are hard to automate:
  - add a launch argument like `--showMainWindowOnLaunch`
- Verify:
  - main window elements exist
  - settings persistence across relaunch

### Test determinism
- Avoid wall-clock dependency: inject `DateProvider`.
- Avoid timers in tests: use controlled scheduling or short intervals behind a test hook.

---

## 8) Delivery format (what to output after each step)

After implementing a step, respond with:

1. **Summary** (1–3 bullets)
2. **Files changed** (list)
3. **How to verify**
   - build steps
   - which tests to run
4. **Notes / assumptions** (only if necessary)

---

## 9) Do’s and Don’ts (quick list)

### Do
- Keep changes minimal and scoped to the requested step.
- Add tests alongside logic.
- Use protocols for external APIs (EventKit).
- Handle errors gracefully and surface them through the view model.

### Don’t
- Don’t implement future features early.
- Don’t add dependencies without explicit instruction.
- Don’t store markers inside events.
- Don’t couple UI directly to EventKit/Core Data.
- Don’t leave the repo in a failing build/test state.

---

## 10) Reference docs inside repo
- Use `AGENTS.md` as the authority for agent behavior.
- Any product/functional requirements will be provided in the task context (do not restate them here).


Техническое задание:
                                            
Ниже — подробное техническое задание (ТЗ) на macOS-приложение для односторонней синхронизации календаря → календарь через EventKit / `EKEventStore`.
---
# 1. Общая идея и цель
**Название (рабочее):** Calendar Mirror (menu-bar)
**Цель:** приложение на macOS выполняет **одностороннюю синхронизацию событий** из **исходного календаря** (Source) в **дочерний календарь** (Child). Источник считается “истиной”. Любые изменения в Source отражаютсяв копиях в Child. Из Child обратно ничего не синхронизируется.
**Особенности:**
* Работает как **menu-bar app**.
* **Dock-иконка отсутствует**, когда рабочее окно закрыто. При открытии окна приложение ведёт себя “как обычное” (активируется, показывает окно).
* Работает только когда пользователь **залогинен**.
* **Автозапуск при логине не нужен**.
---
# 2. Область работ и ограничения
## 2.1 Входит в объём
* Выбор Source/Child календарей (1 пара).
* Настройка “окна синхронизации” (N дней назад и M дней вперёд от now, скользящее).
* Автосинхронизация:
  * по событиям `EKEventStoreChanged` (почти сразу),
  * и fallback таймер **каждые 15 минут**.
* Кнопка **Sync now**.
* Отображение статусов (idle/ok, syncing, error).
* Удаление копий, если оригинал удалён.
* Принудительное перезатирание ручных правок в Child.
* Локальное хранение маппинга “оригинал ↔ копия” в БД (без маркеров внутри событий).
* Функция **Reset sync** (удалить только управляемые приложением события из Child + очистить маппинг).
* Автотесты.
## 2.2 Не входит в объём
* Синхронизация между устройствами.
* Поддержка нескольких пар календарей.
* Уведомления macOS (Notification Center).
* Двусторонняя синхронизация / разрешение конфликтов.
* Копирование `attachments`.
* Копирование `attendees` и `organizer`.
---
# 3. Платформа, SDK, дистрибуция
* **Минимальная macOS:** 14.0
* **Дистрибуция:** **Mac App Store** (sandboxed)
* **UI стек:** SwiftUI + AppKit (для status bar / activation policy)
* **API:** EventKit (`EKEventStore`, `EKEvent`, `EKCalendar`) ([Apple Developer][1])
## 3.1 Доступ к календарю и новые уровни доступа
На macOS 14 EventKit использует обновлённую модель доступа (full access). Приложению требуется **полный доступ к событиям**, т.к. нужно читать Source и создавать/обновлять/удалять в Child. ([Apple Developer][2])
---
# 4. Функциональные требования
## 4.1 Запрос разрешений
1. При первом запуске или при отсутствии разрешения приложение запрашивает доступ к календарям через EventKit.
2. При отказе:
   * статус становится **error**,
   * в рабочем окне показывается причина (нет доступа),
   * кнопка/ссылка “Открыть System Settings → Privacy & Security → Calendars” (deep link опционально; минимум — текстовая подсказка).
3. В `Info.plist` обязателен ключ `NSCalendarsUsageDescription` с понятным описанием.
> Примечание: реализация должна использовать актуальный API запроса “full access” для macOS 14. ([Apple Developer][3])
## 4.2 Выбор календарей
1. В рабочем окне два выпадающих списка:
   * **Source Calendar**: любой календарь EventKit (все аккаунты).
   * **Child Calendar**: любой календарь EventKit, **но только доступный для модификаций**.
2. Если календарь read-only / не поддерживает модификации:
   * он показывается **disabled (серым)**,
   * при наведении — tooltip “Недоступен для записи / read-only”.
3. Если ранее выбранный календарь исчез/удалён/недоступен:
   * статус error,
   * требуется выбрать заново.
## 4.3 Настройка окна синхронизации
1. Два числовых поля/степпера:
   * **Days back** (N ≥ 0)
   * **Days forward** (M ≥ 0)
2. Окно вычисляется как **скользящее от now**:
   * `from = startOfDay(now - N days)`
   * `to = endOfDay(now + M days)`
3. При изменении N/M можно:
   * либо запускать синк автоматически (debounced),
   * либо требовать Sync now (предпочтительно: авто — но с debounce 1–2 сек).
## 4.4 Триггеры синхронизации
1. **EKEventStoreChanged**:
   * подписка на уведомление,
   * при получении — ставим синк в очередь (с debounce/throttle, чтобы не запускать многократно). ([Apple Developer][4])
2. **Fallback таймер**:
   * каждые **15 минут** (если приложение запущено).
3. **Sync now**:
   * доступна из рабочего окна,
   * доступна из menu-bar меню (см. UI).
## 4.5 Правила синхронизации
### 4.5.1 Общие
* Синк **односторонний**: Source → Child.
* Любые ручные изменения в Child по “управляемым” событиям будут **перезатёрты** при следующей синхронизации.
* Приложение не трогает события в Child, которые не принадлежат ему (не находятся в локальной БД маппинга).
### 4.5.2 Создание копии
Для каждого события Source, попавшего в окно синхронизации:
* если копии ещё нет — создать событие в Child и сохранить маппинг.
### 4.5.3 Обновление копии
Если исходное событие изменилось (название, описание, дата/время и любые другие поля из списка ниже), изменения отражаются в копии.
**Важно:** если исходное событие перенесли **вне окна синхронизации**, его копия всё равно должна обновиться (см. алгоритм в разделе 7).
### 4.5.4 Удаление
Если событие **удалено** в Source, соответствующее событие в Child должно быть **удалено**.
### 4.5.5 Какие поля копируются
Копируются **все перечисленные поля**, кроме исключений:
**Копируем:**
* `title`
* `notes` (описание)
* `location`, `structuredLocation` (если задано)
* `startDate`, `endDate`, `isAllDay`, `timeZone`
* `availability`, `status`
* `alarms`
* `url`
* прочие поддерживаемые “обычные” свойства события, не относящиеся к участникам/вложениям
**НЕ копируем:**
* `attendees`
* `organizer`
* `attachments`
## 4.6 Повторяющиеся события (recurrence)
1. Повторяющиеся события **не копируются как серия**.
2. Копирование происходит **по экземплярам**:
   * когда конкретный occurrence попадает в окно синхронизации — создаём/обновляем отдельное (неповторяющееся) событие в Child.
3. Если в Source изменили конкретный occurrence (исключение/перенос) — отражаем это в соответствующей копии (по маппингу).
> Для идентификации occurrences на macOS можно использовать `occurrenceDate` как “оригинальную дату occurrence” для событий из серии. ([Apple Developer][5])
## 4.7 Reset sync
Функция “Reset sync” должна:
1. Удалить в Child **только те события**, которые приложение создало/управляет ими (по записям в локальной БД).
2. Очистить локальную БД маппинга/статусов.
3. После reset — следующий Sync now выполнит “чистую” репликацию окна.
## 4.8 Состояния и ошибки
Приложение обязано различать и отображать:
* нет разрешения / доступ запрещён,
* Source/Child не выбран,
* Child стал read-only,
* ошибки EventKit save/remove,
* ошибки БД (миграция/повреждение),
* “параллельный запуск синка” (должен предотвращаться).
---
# 5. UI/UX требования
## 5.1 Menu-bar
* Иконка в menu-bar отражает состояние:
  * **idle/ok** — обычная,
  * **syncing** — индикатор/спиннер/точка,
  * **error** — красная точка/бейдж.
* **ЛКМ по иконке**: открыть/активировать рабочее окно.
* **ПКМ/Option-клик** (или отдельный пункт в поповере) показывает меню:
  * Open
  * Sync now
  * Reset sync
  * Quit
## 5.2 Рабочее окно (SwiftUI)
Секции:
1. **Calendars**
* Source picker
* Child picker (read-only disabled + tooltip)
2. **Sync window**
* Days back (Stepper/TextField)
* Days forward (Stepper/TextField)
3. **Status**
* Последняя синхронизация: дата/время
* Текущий статус: idle/syncing/error (с текстом)
* Счётчики последнего прогона:
  * Created (сколько создано)
  * Updated
  * Deleted
  * Total managed (в БД)
* Ошибки:
  * список последних N ошибок (например, 20), с временем и текстом
  * кнопка “Copy error” (опционально)
4. **Actions**
* **Sync now**
* **Reset sync**
## 5.3 Поведение Dock-иконки
* Когда нет открытого окна — приложение работает в фоне как menu-bar, **без Dock-иконки**.
* При открытии окна — приложение становится активным “как обычное” (показывает окно, принимает фокус).
* При закрытии окна — возвращается в режим “только menu-bar”.
(Технически это достигается переключением activation policy на `.accessory` / `.regular` и/или настройкой `LSUIElement`, с учётом требований MAS.)
---
# 6. Хранение данных (локальная БД)
Требование: **никаких маркеров в самом событии** (ни в notes, ни в url). Связи храним только локально.
## 6.1 Выбор технологии
Рекомендуемый вариант: **Core Data** (стабильно для MAS, удобно тестировать in-memory).
Альтернатива: SQLite через SPM (GRDB) — допускается, но усложняет зависимость.
В ТЗ принимаем **Core Data** как базовый.
## 6.2 Схема данных (минимум)
Таблица/Entity `SyncedEventLink`:
* `id: UUID`
* `sourceCalendarId: String` (EKCalendar.calendarIdentifier)
* `childCalendarId: String`
* `sourceEventId: String?` (последний известный `eventIdentifier`)
* `sourceCalendarItemId: String?` (опционально для устойчивости)
* `sourceOccurrenceDate: Date?` (для recurring; иначе nil)
* `sourceStartLastSeen: Date`
* `sourceEndLastSeen: Date`
* `childEventId: String` (eventIdentifier копии)
* `lastSyncedAt: Date`
* `lastSeenInSourceAt: Date`
* `lastSyncHash: String` (хэш важного набора полей для быстрого сравнения)
Entity `SyncRun` (опционально, для истории):
* `startedAt`, `finishedAt`
* `createdCount`, `updatedCount`, `deletedCount`
* `errorCount`
Entity `SyncError`:
* `timestamp`
* `domain/code` (если есть)
* `message`
* `context` (какое действие / какой event link)
---
# 7. Алгоритм синхронизации
## 7.1 Общие принципы
* Синк **серийный**: одновременно выполняется только один прогон (через `actor SyncEngine` или single-flight lock).
* Все “триггеры” ставят запрос на синк в очередь, но фактический запуск **debounce** (например, 2–5 секунд) чтобы сгладить шквал `EKEventStoreChanged`.
* Изменения в EventKit желательно батчить с `commit=false` внутри цикла и `commit()` в конце, если это совместимо с API/ошибками.
## 7.2 Получение событий из Source в окне
1. Рассчитать диапазон `[from, to]` по N/M.
2. Построить predicate:
   * только Source calendar
   * диапазон дат `[from, to]`
3. Получить массив `sourceEventsInWindow`.
## 7.3 Идентификатор “ключа” события (для маппинга)
Так как маркеры запрещены, используем ключ:
* для обычного события: `(sourceEventId)` и/или `(sourceCalendarItemId + startDate)`
* для recurring occurrence: `(sourceCalendarItemId + occurrenceDate)` (если доступно) ([Apple Developer][5])
В БД хранится:
* `sourceEventId` (для быстрого `event(withIdentifier:)`)
* `sourceCalendarItemId` + `sourceOccurrenceDate` как fallback
**Причина:** `eventIdentifier` может меняться при смене календаря события. ([Apple Developer][6])
После каждого успешного чтения Source события — обновлять `sourceEventId` в БД на актуальный.
## 7.4 Создание / обновление
Для каждого `sourceEvent` из окна:
1. Найти link в БД:
* сначала по `sourceEventId`,
* иначе fallback по `sourceCalendarItemId + sourceOccurrenceDate` (или + startDate для non-recurring).
2. Если link не найден → **Create**
* Создать новый `EKEvent` в `childCalendar`.
* Скопировать поля согласно разделу 4.5.5.
* Явно очистить/не задавать:
  * attendees/organizer/attachments
  * recurrenceRules (чтобы событие было одиночным)
* `save` в EventKit.
* Сохранить `childEventId` и данные link в БД.
3. Если link найден → **Update**
* Найти child событие через `event(withIdentifier: childEventId)`.
  * если не найдено (удалили вручную) → создать заново и обновить `childEventId`.
* Сравнить hash (или сравнить ключевые поля) и при необходимости перезаписать поля.
* Сохранить.
* Обновить `lastSyncedAt`, `sourceEventId` (на актуальный), `sourceStartLastSeen/sourceEndLastSeen`.
## 7.5 Удаления
После обработки окна:
1. Определить “какие исходные события в окне существуют сейчас”:
* сформировать множество ключей source-событий из `sourceEventsInWindow`.
2. Для каждого link в БД:
* попытаться получить source событие через `event(withIdentifier: sourceEventId)`:
  * если найдено → обновить при необходимости (даже если оно уже вне окна!) и обновить `sourceEventId` если поменялся.
  * если не найдено → считаем, что источник удалён, **НО** перед удалением делаем fallback-проверку:
    * поиск в окне `[from, to]` по fallback-ключу (calendarItemId + occurrenceDate/startDate).
    * если найдено → обновить link на новый `sourceEventId`.
    * если не найдено → **удалить** child событие по `childEventId` и удалить link из БД.
Так обеспечивается требование:
* если событие перенесли **вне окна**, оно не удалится, потому что мы его найдём по `eventIdentifier` и обновим вне зависимости от дат.
* если событие реально удалили, `event(withIdentifier:)` не вернёт его, и копия будет удалена.
## 7.6 Переносы “вне окна”
Ключевое правило из требований: **обновлять даже вне окна**. Это покрывается этапом 7.5, где мы проходим по всем link в БД и “подтягиваем” source по `eventIdentifier` без привязки к диапазону дат.
## 7.7 Сброс синхронизации
* Берём все `childEventId` из БД, удаляем соответствующие события из Child (по одному, с батч-коммитом).
* Очищаем БД.
---
# 8. Архитектура (предлагаемая)
**Модули:**
1. `AppShell` (SwiftUI App) — запуск, окно, состояние.
2. `StatusBarController` (AppKit) — `NSStatusItem`, клики, меню, смена статуса.
3. `PermissionsController` — запрос доступа EventKit, проверка состояния.
4. `SyncEngine` (actor) — вся логика синка, очередь, debounce, single-flight.
5. `EventKitGateway` — тонкая прослойка над `EKEventStore` для моков в тестах.
6. `Persistence` — Core Data stack (production + in-memory для тестов).
7. `Telemetry/Logging` — лог + последние ошибки в БД.
---
# 9. Требования MAS / Sandbox / Privacy
1. Включить App Sandbox.
2. Включить entitlement “Calendars” (read-write доступ к календарю). ([Apple Developer][7])
3. `NSCalendarsUsageDescription` обязателен.
4. Не отправлять данные в сеть (по умолчанию), синк локальный.
5. Не хранить содержимое событий вне нужного минимума (в БД хранится только маппинг/времена/хэши/ошибки, но **не** полные title/notes, если не нужно для диагностики).
---
# 10. Логирование и диагностика
* В памяти + в БД хранить последние N ошибок (например, 20).
* В debug-сборках — расширенный лог (os.Logger).
* В релизе — только существенные ошибки и метрики последнего синка.
---
# 11. Автотесты
## 11.1 Unit tests (обязательно)
* Генерация ключей маппинга (обычные/recurring).
* Логика “Create/Update/Delete” на мокнутом `EventKitGateway`.
* Debounce/throttle и single-flight (не допускается параллельный синк).
* Reset sync удаляет только управляемые события.
* Корректная фильтрация Child календарей (read-only disabled).
## 11.2 Integration-style tests (через fakes)
* Сценарии:
  1. Создание копий в пустом Child
  2. Изменение title/notes/dates → обновление
  3. Удаление source → удаление child
  4. Ручная правка child → перезатирание
  5. Перенос source далеко за окно → обновление всё равно происходит
  6. Recurrence: несколько occurrences → создаются одиночные события
## 11.3 UI tests (минимум)
* Открытие окна из menu-bar действия (на уровне доступного UI, насколько возможно).
* Изменение настроек и отображение статуса.