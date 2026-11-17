# Collaborating with a second GitHub account

This repository is built to be worked on by several people. If you are learning
the workflow on your own, the most realistic way to practise is to play both
roles: **maintainer** on one account and **contributor** on another.

Everything below is the same workflow a real outside contributor would follow.

## The two roles

| Role | Account | Can do |
| --- | --- | --- |
| Maintainer | owns `amanempiricinfotech-hash/SignalBox` | triage and assign issues, review, request changes, approve, merge |
| Contributor | any other GitHub account | fork, branch, commit, open pull requests, respond to review |

The contributor account must **not** be a collaborator on the repository. That
is the point: it should go through a fork, exactly like a stranger would.

## One-time setup for the contributor account

### 1. Fork

Sign in as the contributor account, open the repository and press **Fork**.
That gives you `https://github.com/<contributor>/SignalBox`.

### 2. Clone the fork and add the upstream remote

```bash
git clone https://github.com/<contributor>/SignalBox.git
cd SignalBox
git remote add upstream https://github.com/amanempiricinfotech-hash/SignalBox.git
git remote -v
```

### 3. Work as the right account locally

Set the author identity per clone, so commits are attributed correctly:

```bash
git config user.name  "<contributor name>"
git config user.email "<contributor email>"
```

The email must be one that is verified on the contributor's GitHub account,
otherwise the commits will not be linked to it.

### 4. Authenticate as the right account

The GitHub CLI handles several accounts in one place:

```bash
gh auth login                 # add the contributor account
gh auth status                # list every signed-in account
gh auth switch --user <contributor>   # make it the active one
```

Check before you push or comment:

```bash
gh api user --jq .login
```

If you use HTTPS with a credential helper, the macOS keychain will happily reuse
the wrong token. `gh auth switch` updates the git credential helper too, which is
why it is worth using over a raw token.

## The contribution round trip

### Contributor: pick up an issue

```bash
gh issue list --label "good first issue"
gh issue view 7
gh issue comment 7 --body "I'd like to take this one."
```

Wait to be assigned before starting, so two people do not fix the same bug.

### Maintainer: assign it

```bash
gh auth switch --user amanempiricinfotech-hash
gh issue edit 7 --add-assignee <contributor>
gh issue edit 7 --add-label "in progress"
```

### Contributor: branch, fix, test

```bash
gh auth switch --user <contributor>

git checkout main
git pull upstream main
git checkout -b fix/issue-7-pagination-offset

# make the change, then:
dart format .
flutter analyze
flutter test
```

Add the regression test the issue names. It must fail before your fix and pass
after it. Prove that to yourself by stashing the fix and running the test:

```bash
git stash push lib/         # keep the test, drop the fix
flutter test test/features/notifications/notification_repository_test.dart   # should fail
git stash pop
flutter test test/features/notifications/notification_repository_test.dart   # should pass
```

### Contributor: commit and push

```bash
git commit -am "fix: use the loaded row count as the paging offset"
git push origin fix/issue-7-pagination-offset
```

### Contributor: open the pull request

```bash
gh pr create \
  --repo amanempiricinfotech-hash/SignalBox \
  --base main \
  --head <contributor>:fix/issue-7-pagination-offset \
  --title "fix: use the loaded row count as the paging offset" \
  --body "Fixes #7

The offset was \`items.length + 1\`, which skipped one row at every page
boundary. It is now \`items.length\`.

Added a regression test that loads two pages and asserts the collected ids
match an unpaged query."
```

Or press **Compare & pull request** on GitHub, which fills in the template.

### Maintainer: review

```bash
gh auth switch --user amanempiricinfotech-hash
gh pr list
gh pr view 31
gh pr diff 31
gh pr checks 31
```

Review properly, even playing both roles. Check the acceptance criteria from the
issue one by one, and check that the regression test really covers the bug.

Request changes:

```bash
gh pr review 31 --request-changes --body "The fix is right. Two things:
1. The regression test asserts the count, not the ids, so it would still pass if the wrong row were skipped.
2. \`all()\` and \`page()\` now disagree on ordering - please align them."
```

Approve:

```bash
gh pr review 31 --approve --body "Verified against the steps in #7. Test fails on main and passes here."
```

### Contributor: respond

Push more commits to the same branch; the pull request updates itself. Do not
force-push during review — it makes re-review harder.

```bash
git commit -am "test: assert ids rather than the row count"
git push origin fix/issue-7-pagination-offset
gh pr comment 31 --body "Both addressed. The test now compares ids against the unpaged query."
```

### Maintainer: merge

Only after CI is green and the review is approved:

```bash
gh pr merge 31 --squash --delete-branch
```

Squash merging keeps `main` to one commit per issue. The pull request title
becomes the commit subject, which is why it has to be a good conventional-commit
line.

### Contributor: tidy up

```bash
git checkout main
git pull upstream main
git branch -d fix/issue-7-pagination-offset
git push origin --delete fix/issue-7-pagination-offset   # if GitHub did not
```

## Branch protection

`main` is protected. Nobody pushes to it directly, including the maintainer.

Recommended settings (Settings > Branches > Add rule, pattern `main`):

- Require a pull request before merging, with **1** approval
- Dismiss stale approvals when new commits are pushed
- Require status checks to pass: `Format and analyze`, `Unit and widget tests`, `Build Android APK`
- Require branches to be up to date before merging
- Require conversation resolution before merging
- Do not allow bypassing the above settings

> On a free plan, branch protection rules apply to public repositories. If the
> repository is private on a free plan, protection is not enforced — treat the
> workflow as a convention until it is public or on a paid plan.

A maintainer approving their own pull request is not possible on GitHub. Playing
both roles, let the **contributor** account open pull requests and the
**maintainer** account review and merge them. That keeps the rule satisfied and
the exercise honest.

## Practising review, not just merging

The habit worth building is the review, so give each pull request a real pass:

- Does it fix the cause, or paper over the symptom in the widget layer?
- Does the regression test fail without the fix?
- Was any existing test deleted or weakened to make it pass?
- Is every acceptance criterion from the issue met?
- Is anything unrelated bundled in?
- Would you understand this diff in six months?

Requesting changes at least once per exercise is the point. Approving everything
teaches nothing.
