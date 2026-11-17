# Contributing to SignalBox

Thanks for taking an interest. This repository exists to be contributed to: it
ships with catalogued bugs and unfinished features so that there is always real
work available at every experience level.

## Before you start

1. Read the [README](README.md) and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
2. Get the project running locally and the tests passing:

   ```bash
   flutter pub get
   flutter analyze
   flutter test
   ```

   All 124 tests must pass on a clean checkout. If they do not, open an issue
   before changing anything.

3. Pick an issue and **comment on it to be assigned**. One contributor per
   issue; do not start work on an issue already assigned to someone else.

## Picking an issue

| Label | Who it is for |
| --- | --- |
| [`good first issue`](../../labels/good%20first%20issue) | First contribution here. Scoped to one or two files. |
| [`beginner`](../../labels/beginner) | UI fixes, docs, validation, small tests. No need to understand the whole codebase. |
| [`intermediate`](../../labels/intermediate) | Repository logic, SQL, filtering and sorting, Riverpod state. |
| [`advanced`](../../labels/advanced) | Kotlin platform code, schema migrations, background work, performance. |

Every issue states its problem, reproduction steps, expected result, acceptance
criteria, the regression test to add, and its difficulty. If any of that is
unclear or wrong, say so on the issue — that is useful feedback.

Some issues depend on others. Dependencies are stated in the issue body; check
them before you start.

## Workflow

SignalBox uses a fork-and-pull-request workflow. Nobody pushes to `main`.

```bash
# 1. Fork the repository on GitHub, then clone your fork
git clone https://github.com/<your-username>/SignalBox.git
cd SignalBox
git remote add upstream https://github.com/amanempiricinfotech-hash/SignalBox.git

# 2. Start from an up-to-date main
git checkout main
git pull upstream main

# 3. Branch
git checkout -b fix/issue-5-snooze-boundary

# 4. Work, then verify
dart format .
flutter analyze
flutter test

# 5. Commit and push
git commit -am "fix: compare snooze window against the current time"
git push origin fix/issue-5-snooze-boundary

# 6. Open a pull request against upstream main
```

### Branch naming

`<type>/issue-<number>-<short-description>`

```
feature/issue-12-export-notifications
fix/issue-5-search-filter
docs/issue-18-update-readme
test/issue-21-add-widget-tests
perf/issue-24-database-indexes
refactor/issue-27-simplify-query-builder
```

### Commit messages

[Conventional Commits](https://www.conventionalcommits.org/). One logical change
per commit; a subject in the imperative mood, 72 characters or fewer.

```
feat: add notification export
fix: correct notification filtering
test: add notification repository tests
docs: improve contribution guide
refactor: simplify notification service
perf: add index on notification_items.posted_at
chore: bump flutter_lints to 5.0.0
```

Explain *why* in the body when the reason is not obvious from the diff. Reference
the issue in the pull request, not in every commit.

## Pull request requirements

A pull request is ready for review when:

- [ ] It references its issue (`Fixes #12`).
- [ ] It changes one thing. Unrelated fixes belong in their own pull request.
- [ ] `dart format --output=none --set-exit-if-changed .` passes.
- [ ] `flutter analyze` reports no issues.
- [ ] `flutter test` passes.
- [ ] **It adds or updates tests.** A bug fix needs a regression test that fails before the change and passes after it.
- [ ] Every acceptance criterion in the issue is met, and you say so explicitly.
- [ ] UI changes include before/after screenshots, in light and dark theme.
- [ ] No new dependency without a justification.
- [ ] No unrelated reformatting. Keep the diff reviewable.
- [ ] Existing behaviour outside the issue's scope is unchanged.

Fill in the [pull request template](.github/PULL_REQUEST_TEMPLATE.md) — it is
that checklist, and reviewers use it.

### A note on the seeded bugs

Fixing a seeded bug means fixing the **cause**, not the symptom. A change that
patches over the result in the widget layer while the repository still returns
wrong data will be asked for rework.

Do not delete or weaken an existing test to make your change pass. No existing
test encodes a seeded bug, so you should never need to. If one seems to, say so
on the issue.

## Review

Maintainers review within a few days. Expect questions: this is a learning
repository and review is part of the exercise.

- Respond to feedback by pushing more commits; do not force-push during review, it makes re-review harder.
- Mark conversations resolved once you have addressed them.
- A pull request needs one maintainer approval and passing CI before it can merge.
- Pull requests are squash-merged, so your branch's commit history is tidied for you. Make the PR title a good conventional-commit subject.

If you go quiet for two weeks on an assigned issue, it may be unassigned so
someone else can pick it up. No hard feelings — just say if you need longer.

## Code style

- `dart format` is the authority. No hand formatting.
- `flutter analyze` must be clean. Do not add `// ignore:` without a comment explaining why.
- Keep widgets small and reusable; a widget whose `build` method needs scrolling probably wants splitting.
- All SQL lives in `features/*/data`. Widgets and providers never build SQL.
- Keep business logic out of widgets. If it can be a pure function in `domain/`, make it one.
- Prefer a small named widget class over a `_buildSomething()` method, so Flutter can skip rebuilding it.
- Comment the *why*, not the *what*. Delete commented-out code.
- No new abstraction layer without a second caller.
- Null safety is non-negotiable: no `!` on something you have not just checked.

## Reporting a bug

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml). First check
[`docs/SEEDED_BUGS.md`](docs/SEEDED_BUGS.md) and the open issues — the seeded
bugs are known and already tracked.

A bug report needs exact reproduction steps from a known starting state, what you
expected, what happened, and your `flutter doctor -v` output.

## Proposing a feature

Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.yml).
Check [`docs/MISSING_FEATURES.md`](docs/MISSING_FEATURES.md) first; the big gaps
are already scoped and waiting.

Features that would require a backend, an account, or sending notification
content off the device are out of scope. SignalBox is local-first by design.

## Security

Do not open a public issue for a security problem. Follow
[`SECURITY.md`](SECURITY.md).
