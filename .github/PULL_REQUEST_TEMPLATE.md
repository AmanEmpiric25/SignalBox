## What does this change?

<!-- One or two sentences. What is different after this pull request? -->

## Related issue

<!-- Required. Use "Fixes #12" so the issue closes on merge, or "Refs #12". -->

Fixes #

## Type of change

- [ ] Bug fix (one of the seeded bugs, or a genuine defect)
- [ ] New feature (one of the unfinished features)
- [ ] Code quality: performance, accessibility, refactoring
- [ ] Tests only
- [ ] Documentation only

## How did you verify it?

<!--
Be specific. "Tested manually" is not enough.
For a bug fix: the exact steps from the issue, and what you now see instead.
-->

1.
2.
3.

## Acceptance criteria

<!--
Copy the checklist from the issue and tick what you have met.
If you cannot meet one, say so and explain why.
-->

- [ ]
- [ ]

## Tests

- [ ] I added or updated tests for this change
- [ ] For a bug fix: my regression test **fails before** my change and **passes after** it
- [ ] `flutter test` passes locally

Which tests did you add, and what do they assert?

<!-- e.g. test/features/notifications/notification_repository_test.dart: asserts a body-only search match is returned -->

## Screenshots

<!--
Required for any UI change. Before and after, in light and dark theme.
Delete this section for a change with no visual effect.
-->

| Before | After |
| --- | --- |
|  |  |

## Checklist

- [ ] `dart format --output=none --set-exit-if-changed .` passes
- [ ] `flutter analyze` reports no issues
- [ ] `flutter test` passes
- [ ] The change is focused on one issue; no unrelated fixes bundled in
- [ ] No unrelated reformatting in the diff
- [ ] No new dependency (or: a new dependency is justified below)
- [ ] Behaviour outside this issue's scope is unchanged
- [ ] I did not delete or weaken an existing test to make this pass
- [ ] Public APIs I added or changed have doc comments
- [ ] I read [CONTRIBUTING.md](../blob/main/CONTRIBUTING.md)

## New dependencies

<!-- Name them and justify each. Delete if none. -->

None.

## Anything the reviewer should know

<!--
Trade-offs, alternatives you rejected, follow-up work you deliberately left out,
or parts you are unsure about. Saying "I am not sure about X" is welcome here.
-->
