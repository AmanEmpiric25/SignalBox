#!/usr/bin/env bash
#
# Publishes this repository to a GitHub account, end to end:
#
#   1. creates <owner>/<repo> (public by default)
#   2. pushes the current branch as main
#   3. creates the labels, milestones and all 27 issues
#   4. protects main
#
# Idempotent: an existing repo is reused, and labels, milestones and issues
# that already exist are updated or skipped rather than duplicated.
#
# You must be authenticated as <owner> (or have write access to it):
#
#   gh auth login                     # add the account, interactive
#   gh auth switch --user <owner>     # make it active
#
# Usage:
#   ./tools/github/publish_to.sh <owner> [repo-name] [public|private]
#
# Example:
#   ./tools/github/publish_to.sh AmanEmpiric25 SignalBox public

set -euo pipefail

OWNER="${1:-}"
REPO_NAME="${2:-SignalBox}"
VISIBILITY="${3:-public}"

if [[ -z "$OWNER" ]]; then
  echo "usage: $0 <owner> [repo-name] [public|private]" >&2
  exit 1
fi
if [[ "$VISIBILITY" != "public" && "$VISIBILITY" != "private" ]]; then
  echo "visibility must be 'public' or 'private'" >&2
  exit 1
fi

SLUG="$OWNER/$REPO_NAME"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE="${REMOTE_NAME:-$OWNER}"

for binary in gh jq git; do
  command -v "$binary" >/dev/null || { echo "$binary is required" >&2; exit 1; }
done

ACTIVE="$(gh api user --jq .login 2>/dev/null || true)"
if [[ -z "$ACTIVE" ]]; then
  echo "gh is not authenticated. Run: gh auth login" >&2
  exit 1
fi
if [[ "$ACTIVE" != "$OWNER" ]]; then
  cat >&2 <<MSG
gh is authenticated as '$ACTIVE', but you asked to publish to '$OWNER'.

If '$OWNER' is your account, add it and switch:

    gh auth login
    gh auth switch --user $OWNER

Then run this script again.
MSG
  exit 1
fi

echo "==> Repository"
if gh repo view "$SLUG" >/dev/null 2>&1; then
  echo "    exists: $SLUG"
else
  gh repo create "$SLUG" \
    --"$VISIBILITY" \
    --description "SignalBox - a local-first smart notification manager for Android, built with Flutter. An open-source learning repository with catalogued bugs and unfinished features, built for collaboration." \
    >/dev/null
  echo "    created: $SLUG ($VISIBILITY)"
fi

echo "==> Pushing"
if git remote get-url "$REMOTE" >/dev/null 2>&1; then
  git remote set-url "$REMOTE" "https://github.com/$SLUG.git"
else
  git remote add "$REMOTE" "https://github.com/$SLUG.git"
fi
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git push -u "$REMOTE" "$BRANCH:main"
echo "    pushed $BRANCH -> $SLUG main"

echo "==> Labels, milestones and issues"
"$HERE/setup_github.sh" "$SLUG"

echo "==> Protecting main"
protection="$(mktemp)"
cat > "$protection" <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Format and analyze", "Unit and widget tests", "Build Android APK"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
# enforce_admins is left OFF so that you, the owner, can still push setup
# commits directly. Contributors still need a reviewed pull request. Turn it on
# with:
#   gh api -X POST repos/<owner>/<repo>/branches/main/protection/enforce_admins
if gh api -X PUT "repos/$SLUG/branches/main/protection" --input "$protection" --silent 2>/dev/null; then
  echo "    main protected (1 approval, 3 required checks, admins exempt)"
else
  echo "    could not protect main - on a free plan this needs a public repo"
fi
rm -f "$protection"

echo
echo "Done: https://github.com/$SLUG"
echo
echo "Still manual:"
echo "  - Project board:  gh auth refresh -s project,read:project"
echo "                    ./tools/github/create_project_board.sh $OWNER $SLUG"
