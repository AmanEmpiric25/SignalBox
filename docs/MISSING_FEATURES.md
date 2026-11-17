# Intentionally unfinished features

These features are **not implemented**. Most of them have some groundwork in
place (a data-layer method, a persisted setting, a disabled UI entry) and the
app states plainly in the interface where a feature is missing, rather than
pretending it works.

Nothing here is disguised as a bug, and nothing here is a placeholder file
created to pad the repository: every entry is a real gap with a defined scope.

## Index

| ID | Feature | Area | Difficulty |
| --- | --- | --- | --- |
| `F1` | export notification history to CSV | settings / data | Intermediate |
| `F2` | apply notification rules to incoming notifications | rules / core | Advanced |
| `F3` | create, rename and delete custom categories | categories | Intermediate |
| `F4` | bulk notification management with multi-select | notifications | Intermediate |
| `F5` | scheduled daily notification summary | settings / background work | Advanced |
| `F6` | backup and restore the local database | settings / data | Advanced |
| `F7` | enforce the configurable data retention window (needs `B10` first) | settings / data | Intermediate |
| `F8` | group the inbox by application | notifications / UI | Intermediate |
| `F9` | per-application analytics screen | statistics / applications | Intermediate |
| `F10` | search improvements - recent searches and match highlighting (needs `B1` first) | notifications / search | Beginner |

---

## `F1` export notification history to CSV

**Area:** settings / data  
**Difficulty:** Intermediate  
**Labels:** `feature`, `help wanted`, `intermediate`, `priority: medium`

### Problem statement

SignalBox is local-first and deliberately has no backend, which means users currently have no way to get their own data out of the app. There is no export, so the history cannot be analysed elsewhere or kept after an uninstall.

### Current state

Settings > Data > **Export history to CSV** exists and shows a "not implemented yet" snackbar.

**Likely files**

- `lib/features/settings/presentation/settings_page.dart`
- `lib/features/notifications/data/notification_repository.dart`

### User story

> As a SignalBox user I want to export my notification history as a CSV file so that I can analyse it in a spreadsheet and keep a copy outside the app.

### Functional requirements

- Export every notification matching the filter the user chooses: all history, or the currently active inbox filter.
- Columns: `posted_at` (ISO 8601 local time), `package_name`, `app_label`, `title`, `body`, `priority`, `category`, `is_read`, `is_archived`.
- Escape the CSV correctly: quote fields containing commas, quotes or newlines, and double embedded quotes.
- Write the file to a user-visible location and offer the system share sheet.
- Show progress for large exports and keep the UI responsive.
- Report the row count and the file path on success; show a recoverable error on failure.

### Expected UI behaviour

A bottom sheet offering **All notifications** or **Current filter**, then a progress indicator, then a snackbar with the result and a **Share** action.

### Technical considerations

- Stream rows from SQLite instead of loading everything into memory; add a repository method that returns an iterable/stream.
- Use `path_provider` for the target directory; no new dependency is required for CSV writing.
- Do the string building in an isolate (`compute`) if a benchmark shows it blocking the frame budget.

### Acceptance criteria

- [ ] Exporting produces a file that opens in a spreadsheet with one header row and one row per notification.
- [ ] A notification whose body contains a comma, a double quote and a newline survives a round trip through the CSV.
- [ ] Exporting an empty history produces a file with only the header row and says so, rather than failing.
- [ ] The export runs off the UI thread; the screen does not freeze for a 10,000-row export.
- [ ] The success message names the file location.

### Testing requirements

- Unit tests for the CSV encoder: commas, quotes, newlines, empty fields, unicode.
- A repository test for the streaming query.
- A widget test asserting the export sheet appears and the success message is shown.

---

## `F2` apply notification rules to incoming notifications

**Area:** rules / core  
**Difficulty:** Advanced  
**Labels:** `feature`, `help wanted`, `advanced`, `priority: high`

### Problem statement

The whole point of the Rules screen is to automate priority and categorisation, but no evaluation engine exists. Rules are inert data, so users have to triage every notification by hand.

### Current state

Rules can be created, edited, enabled and deleted, and are persisted. A banner on the Rules screen states they are not applied. `RuleAction` and `RuleMatchField` are defined but nothing evaluates them.

**Likely files**

- `lib/features/rules/data/rule_repository.dart`
- `lib/core/services/notification_access_service.dart`

### User story

> As a SignalBox user I want my rules applied to notifications as they arrive so that important notifications are prioritised and categorised without me touching them.

### Functional requirements

- Evaluate enabled rules in `sortOrder` order against every incoming notification.
- Support all four actions: set priority, assign category, mute the application, auto-snooze for N minutes.
- Support all three match fields: package name, title, body.
- Define and document the semantics of multiple matches (first match wins, or last writer wins per action).
- Matching must be case insensitive and must treat the stored value as literal text, not a pattern.
- A rule referring to a deleted category must not break ingestion.
- Offer a **Test rule** affordance that reports how many stored notifications a rule would match.
- Remove the "not applied" banner once the engine is live.

### Expected UI behaviour

No new screen. The Rules screen loses its warning banner and gains a **Test rule** button showing the match count.

### Technical considerations

- Put the evaluation in a pure `RuleEngine` class in `lib/features/rules/domain/` that takes a notification plus a rule list and returns the resulting values. Keep the database out of it so it can be unit-tested.
- Call the engine from the ingestion path that consumes `NotificationAccessService.stream()`.
- Think about ordering: rules are evaluated once at ingestion. Decide and document whether editing a rule re-applies it to existing history (a separate follow-up is fine).

### Acceptance criteria

- [ ] A new notification matching an enabled `setPriority` rule is stored with that priority.
- [ ] A notification matching an `assignCategory` rule is stored with that category id.
- [ ] A notification from an app muted by a rule is stored in history but kept out of the inbox.
- [ ] An `autoSnooze` rule stores a `snooze_until` N minutes in the future.
- [ ] Disabled rules never apply.
- [ ] Rule evaluation is pure and unit-tested without a database.
- [ ] Ingestion still succeeds when a rule's target category no longer exists.

### Testing requirements

- Unit tests for `RuleEngine` covering every action and match field, plus no-match and multi-match cases.
- A test asserting disabled rules are skipped.
- An integration test through the repository asserting a stored notification carries the rule's effects.

---

## `F3` create, rename and delete custom categories

**Area:** categories  
**Difficulty:** Intermediate  
**Labels:** `feature`, `help wanted`, `intermediate`, `priority: medium`

### Problem statement

Users are limited to five fixed buckets that cannot express their own organisation (Work, Family, Deliveries). The data layer already supports custom categories; only the UI and validation are missing.

### Current state

`CategoryRepository.create`, `update` and `delete` exist and are tested. The Categories screen lists the five read-only system categories, and its **New category** button shows a "not implemented yet" snackbar.

**Likely files**

- `lib/features/categories/presentation/categories_page.dart`
- `lib/features/categories/data/category_repository.dart`

### User story

> As a SignalBox user I want to create my own categories with my own colours so that notifications are grouped the way I think about them.

### Functional requirements

- Create a category with a name and a colour chosen from a palette.
- Rename and recolour user categories.
- Delete a user category; notifications keep existing and become uncategorised.
- System categories stay read-only and cannot be deleted.
- Validate the name: non-empty, trimmed, at most 60 characters, and unique (case insensitive).
- Surface the uniqueness failure as a form error rather than a crash.

### Expected UI behaviour

A bottom sheet with a name field and a colour swatch row. Tapping a user category opens the same sheet in edit mode with a **Delete** action.

### Technical considerations

- The `categories.name` column already has a UNIQUE constraint; catch the constraint violation and map it to a form error.
- `ON DELETE SET NULL` is already declared on `notification_items.category_id`, and `PRAGMA foreign_keys` is on.
- Invalidate `categoriesProvider`, `categoriesByIdProvider` and `categoryCountsProvider` after a write.

### Acceptance criteria

- [ ] A created category appears in the list, in the inbox filter sheet and in the notification detail picker.
- [ ] A duplicate name is rejected with a visible form error and nothing is written.
- [ ] Deleting a category sets `category_id` to NULL on its notifications instead of deleting them.
- [ ] The lock icon and the absence of edit affordances on system categories are preserved.
- [ ] The category list shows the live notification count per category.

### Testing requirements

- Repository tests for duplicate names and for the SET NULL behaviour on delete.
- Widget tests for validation errors and for the create-then-appears flow.

---

## `F4` bulk notification management with multi-select

**Area:** notifications  
**Difficulty:** Intermediate  
**Labels:** `feature`, `help wanted`, `intermediate`, `priority: medium`

### Problem statement

Clearing out a backlog means repeating a long-press and a menu tap for every notification. There is no way to act on many at once, which makes the app impractical after a few days of capture.

### Current state

`NotificationRepository.deleteMany` and `InboxNotifier.deleteMany` exist and are tested. Nothing in the UI can select more than one notification.

**Likely files**

- `lib/features/notifications/presentation/inbox_page.dart`
- `lib/features/notifications/presentation/providers/notification_providers.dart`

### User story

> As a SignalBox user I want to select several notifications and act on them in one go so that I can clear a backlog quickly.

### Functional requirements

- Enter selection mode from a long-press or an explicit **Select** action.
- Select and deselect individual rows, plus **Select all** for the current filtered view.
- Bulk actions: mark read, mark unread, archive, snooze, delete.
- A contextual app bar shows the selection count and the available actions.
- Deleting more than one notification asks for confirmation and offers undo.
- Leaving selection mode clears the selection.

### Expected UI behaviour

A contextual app bar replacing the normal one, checkboxes (or avatar check overlays) on rows, and a bottom action bar.

### Technical considerations

- Hold the selected ids in a `Notifier<Set<int>>` so the list rows can watch only what they need.
- For undo, soft-delete into memory and commit after the snackbar closes, or re-insert on undo. Document the chosen approach.
- `deleteMany` already batches a single SQL statement; keep bulk work to one statement per action.

### Acceptance criteria

- [ ] Selecting three notifications and choosing **Archive** archives exactly those three.
- [ ] **Select all** selects every notification matching the active filter, not just the loaded page.
- [ ] The unread counter, the inbox and the Apps tab all refresh after a bulk action.
- [ ] A bulk delete can be undone from the snackbar and fully restores the rows.
- [ ] Selection mode is announced to screen readers and the selection count is readable.

### Testing requirements

- Notifier tests for select, deselect, select-all and each bulk action.
- A widget test entering selection mode and asserting the contextual app bar and count.
- A test asserting undo restores the deleted rows.

---

## `F5` scheduled daily notification summary

**Area:** settings / background work  
**Difficulty:** Advanced  
**Labels:** `feature`, `help wanted`, `advanced`, `priority: low`

### Problem statement

SignalBox can tell a user how noisy their day was, but only if they open the app. There is no scheduled digest, so the insight never reaches them.

### Current state

Settings > Privacy > **Daily summary notification** persists a boolean and says scheduling is not wired up. Nothing is scheduled and no summary notification is ever posted.

**Likely files**

- `lib/features/settings/presentation/settings_page.dart`
- `android/app/src/main/kotlin/com/signalbox/signalbox/`

### User story

> As a SignalBox user I want a daily summary at a time I choose so that I learn what I missed without opening the app.

### Functional requirements

- Let the user pick the delivery time; default to 21:00 local time.
- Post a local notification summarising the day: total captured, the three busiest apps, and the number of unread high-priority notifications.
- Tapping the summary opens the Statistics screen for today.
- Survive a device reboot (the manifest already declares `RECEIVE_BOOT_COMPLETED`).
- Respect Android 13+ `POST_NOTIFICATIONS` runtime permission, and request it only when the user enables the feature.
- Turning the setting off cancels any pending work.
- Never include notification body text in the summary, so the digest cannot leak content on a lock screen.

### Expected UI behaviour

A time picker under the toggle, and a subtitle showing the next scheduled delivery.

### Technical considerations

- Use `WorkManager` with a periodic request, or `AlarmManager` with an exact-ish alarm, on the Kotlin side. Discuss the trade-off in the PR: WorkManager is battery friendly but not minute-precise.
- Build the summary text in Dart from the existing `StatisticsRepository` and hand it to the platform side, or query SQLite from Kotlin. Prefer the former to keep one source of truth.
- Add a debug-only **Send summary now** action so the behaviour can be reviewed without waiting.

### Acceptance criteria

- [ ] Enabling the setting and picking a time schedules exactly one recurring job.
- [ ] The summary arrives at the chosen local time, including after a reboot.
- [ ] The counts in the summary match the Statistics screen for the same day.
- [ ] Disabling the setting cancels the job and no further summaries arrive.
- [ ] Denying the notification permission turns the setting back off and explains why.
- [ ] Daylight-saving and timezone changes do not double-post or skip a day.

### Testing requirements

- Unit test the summary text builder against a fixed statistics payload, including the empty-day case.
- Unit test the scheduling controller with a fake platform channel: enable schedules, disable cancels.
- Document the manual verification steps for reboot and timezone change in the PR.

---

## `F6` backup and restore the local database

**Area:** settings / data  
**Difficulty:** Advanced  
**Labels:** `feature`, `help wanted`, `advanced`, `priority: low`

### Problem statement

Everything SignalBox knows lives in one SQLite file on one device. Changing phones or clearing app data loses the entire history, and there is no supported way to move it.

### Current state

Settings > Data > **Backup and restore** exists and shows a "not implemented yet" snackbar.

**Likely files**

- `lib/features/settings/presentation/settings_page.dart`
- `lib/core/database/app_database.dart`

### User story

> As a SignalBox user I want to back my data up to a file and restore it on another device so that my history survives a phone change.

### Functional requirements

- Export notifications, applications, categories, rules and preferences into a single versioned archive.
- Include a schema version and an app version in the archive, and refuse to restore an archive from a newer schema.
- Restore must either replace the current data or merge it; the choice must be explicit and explained.
- Validate the archive before writing anything, and leave the database untouched if validation fails.
- Restore inside a transaction so a failure cannot leave a half-restored database.
- Warn clearly before a destructive restore.

### Expected UI behaviour

Two entries, **Back up now** and **Restore from file**, a confirmation dialog naming what will be overwritten, and a progress indicator.

### Technical considerations

- Prefer a JSON archive over copying the raw `.sqlite` file: it is inspectable, diffable in review, and portable across schema versions.
- Reuse the migration machinery in `AppDatabase` for older archives.
- Keep ids out of the archive, or remap them on restore, so merge mode cannot collide.

### Acceptance criteria

- [ ] A backup taken on one device restores on another with identical counts in every table.
- [ ] Restoring a truncated or malformed file fails with a clear message and changes nothing.
- [ ] Restoring an archive whose schema version is newer is refused with an explanation.
- [ ] A replace-restore leaves no rows from before the restore.
- [ ] Preferences (theme, retention, privacy) are restored too.

### Testing requirements

- Round-trip test: seed, back up, wipe, restore, assert table contents match.
- Tests for malformed input, a newer schema version and an empty database.
- A test asserting a failed restore rolls back.

---

## `F7` enforce the configurable data retention window

**Area:** settings / data  
**Difficulty:** Intermediate  
**Labels:** `feature`, `help wanted`, `intermediate`, `priority: medium`

**Depends on:** seeded bug `B10`

### Problem statement

The app promises to keep history for a chosen window, but never deletes anything. The database grows without bound and the setting is decorative. Note this feature is blocked by the retention persistence bug.

### Current state

`NotificationRepository.deleteOlderThan` is implemented and tested. The retention setting is stored and shown in Settings. Nothing ever calls the cleanup.

**Likely files**

- `lib/features/settings/presentation/settings_page.dart`
- `lib/features/notifications/data/notification_repository.dart`

### User story

> As a SignalBox user I want notifications older than my retention window deleted automatically so that the app does not grow forever and old content does not linger on my device.

### Functional requirements

- Run the cleanup on app start and then at most once a day.
- Never delete anything when the setting is `Forever` (0).
- Report what was removed: show the number of deleted notifications in Settings as a last-run summary.
- Lowering the retention window takes effect on the next cleanup, and the destructive consequence is explained before the value is saved.
- Do not block the first frame on cleanup.

### Expected UI behaviour

A subtitle under **Keep history for** reading e.g. `Last cleanup removed 42 notifications`, plus a confirmation dialog when shortening the window.

### Technical considerations

- Store the last-run timestamp in `SharedPreferences` with a key added to `PrefKeys`.
- Depends on the retention persistence bug being fixed first; otherwise the window always reads as the default.
- Invalidate the inbox, counters and statistics providers after a cleanup that deleted rows.

### Acceptance criteria

- [ ] With retention set to 7 days, notifications older than 7 days are gone after a restart and newer ones remain.
- [ ] With `Forever` selected, nothing is deleted.
- [ ] The cleanup runs at most once per calendar day even across several app starts.
- [ ] Choosing a shorter window shows a confirmation that states roughly how many notifications it will remove.
- [ ] Start-up time is not measurably affected.

### Testing requirements

- A test asserting rows past the cutoff are deleted and others are kept.
- A test asserting `Forever` deletes nothing.
- A test asserting the once-a-day guard prevents a second run.

---

## `F8` group the inbox by application

**Area:** notifications / UI  
**Difficulty:** Intermediate  
**Labels:** `feature`, `help wanted`, `intermediate`, `priority: medium`

### Problem statement

The inbox is a single chronological stream. With a dozen noisy apps the important ones are buried, and the preference that promises app grouping does nothing.

### Current state

Settings > Inbox > **Group inbox by application** persists a boolean and says so in its subtitle. The inbox always groups by day.

**Likely files**

- `lib/features/notifications/presentation/inbox_page.dart`
- `lib/features/settings/presentation/settings_page.dart`

### User story

> As a SignalBox user I want the inbox grouped by application so that I can collapse the noisy apps and read the ones I care about.

### Functional requirements

- When the setting is on, group rows under a per-application header showing the app name, its total and its unread count.
- Order groups by most recent activity; order notifications inside a group newest first.
- Let a group be collapsed and expanded, and remember that per app across restarts.
- Keep search, filters and pagination working in both grouping modes.
- Switching the setting updates the inbox without a restart.

### Expected UI behaviour

Sticky app headers with an avatar, the app name, a count badge and a chevron.

### Technical considerations

- Pagination plus grouping is the hard part: either fetch a page and regroup what is loaded (document that groups are partial), or query per app. Describe the choice in the PR.
- Reuse `AppAvatar` and the existing header styling in `_InboxList._buildRows`.
- Collapse state belongs in `SharedPreferences` through a `PrefKeys` entry, keyed by package name.

### Acceptance criteria

- [ ] Turning the setting on regroups the inbox immediately.
- [ ] Group totals equal the number of rows in the group.
- [ ] Collapsing a group hides its rows and survives an app restart.
- [ ] Searching inside app grouping shows only groups with matches, and hides empty groups.
- [ ] Pagination still loads more notifications while grouped, without duplicating group headers.

### Testing requirements

- Widget tests for grouped rendering, collapse/expand, and search inside grouping.
- A unit test for the grouping function covering an empty list, one app and several apps.

---

## `F9` per-application analytics screen

**Area:** statistics / applications  
**Difficulty:** Intermediate  
**Labels:** `feature`, `help wanted`, `intermediate`, `priority: low`

### Problem statement

A user can see that an app is noisy overall but not when it is noisy, or whether it got worse. There is no per-app trend, busiest hour or week-on-week comparison.

### Current state

The app detail screen lists notifications only. Statistics are global, with a single application chip filter.

**Likely files**

- `lib/features/applications/presentation/app_detail_page.dart`
- `lib/features/statistics/data/statistics_repository.dart`

### User story

> As a SignalBox user I want analytics for a single application so that I can decide whether to mute it.

### Functional requirements

- Add an **Insights** tab to the app detail screen.
- Show notifications per day for the last 30 days, the busiest hour of the day, the split by priority and category, and the change against the previous period.
- Show the quiet hours during which this app never notifies.
- Offer a **Mute this app** action from the insights view.
- Handle apps with very little data without misleading charts.

### Expected UI behaviour

A `TabBar` with **History** and **Insights**; stat cards, a daily bar chart and an hour-of-day distribution.

### Technical considerations

- Extend `StatisticsRepository` with an hour-of-day aggregate rather than grouping in Dart; SQLite's `strftime` can do it.
- Reuse `SimpleBarChart` and `BreakdownBar`; no charting dependency is needed.
- Watch the N+1 query risk: fetch the aggregates in as few statements as possible.

### Acceptance criteria

- [ ] The per-day numbers match the global statistics when filtered to the same app and range.
- [ ] The busiest hour is computed in local time.
- [ ] An app with one notification shows a sensible view instead of an empty or broken chart.
- [ ] The week-on-week delta is correct in both directions and reads clearly when the previous period was empty.
- [ ] Every chart has a text alternative for screen readers.

### Testing requirements

- Repository tests for the hour-of-day aggregate, including a timezone-sensitive case.
- A test for the period-over-period delta, including an empty previous period.
- Widget tests for the insights tab with rich and sparse data.

---

## `F10` search improvements - recent searches and match highlighting

**Area:** notifications / search  
**Difficulty:** Beginner  
**Labels:** `feature`, `good first issue`, `beginner`, `priority: low`

**Depends on:** seeded bug `B1`

### Problem statement

Every keystroke runs a new query, nothing shows the user why a row matched, and a search has to be retyped from scratch every time.

### Current state

Search is a plain text field that filters as you type. There is no history, no highlighting and no debounce.

**Likely files**

- `lib/features/notifications/presentation/inbox_page.dart`

### User story

> As a SignalBox user I want my recent searches and highlighted matches so that searching is faster and I can see what matched.

### Functional requirements

- Debounce the query so typing does not issue a query per keystroke.
- Highlight the matched substring in the title and body of each result.
- Keep the last five searches and offer them when the field is focused and empty.
- Let a recent search be removed, and offer **Clear history**.
- Recent searches persist across restarts.

### Expected UI behaviour

A dropdown of recent searches below the field; matched text in a tinted span.

### Technical considerations

- Debounce with a `Timer` in the notifier, not in the widget, so the behaviour is testable.
- Build highlighting with `Text.rich` and `TextSpan` ranges; take care with overlapping or repeated matches.
- Store recent searches as a string list in `SharedPreferences` through a new `PrefKeys` entry.
- Depends on the body-search fix, otherwise highlighting in the body will never have anything to highlight.

### Acceptance criteria

- [ ] Typing `invoice` quickly issues one query rather than seven.
- [ ] The matched substring is visually distinct in the result rows, in both light and dark themes.
- [ ] Highlighting is case insensitive and highlights every occurrence.
- [ ] Recent searches appear when the empty field is focused, and selecting one runs it.
- [ ] Nothing is highlighted when the query is empty.

### Testing requirements

- A unit test for the span builder: no match, one match, several matches, different case, empty query.
- A test asserting the debounce collapses rapid input into one query.
- A test asserting recent searches round-trip through preferences and cap at five.
