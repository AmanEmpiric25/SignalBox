# GitHub setup tooling

`issues.json` is the generated catalogue of all 27 issues: title, labels,
milestone and the full markdown body. It is the single source that
`docs/SEEDED_BUGS.md`, `docs/MISSING_FEATURES.md` and `docs/IMPROVEMENTS.md`
were written from, so the issues and the docs cannot drift apart.

`setup_github.sh` creates the labels, milestones and issues on a repository.

```bash
# see what it would do, without touching GitHub
DRY_RUN=1 ./tools/github/setup_github.sh amanempiricinfotech-hash/SignalBox

# do it
./tools/github/setup_github.sh amanempiricinfotech-hash/SignalBox
```

It is idempotent: existing labels and milestones are updated, and an issue whose
exact title already exists is skipped. Running it twice will not create
duplicates.

Requires `gh` (authenticated as an account with write access to the repository)
and `jq`.

## If you fork this repository

Run the script against your own fork to get the same 27 issues, so you can
practise the whole workflow on a repository you own:

```bash
./tools/github/setup_github.sh <your-username>/SignalBox
```

The board is not created by the script. GitHub Projects v2 needs a few manual
steps; see [`docs/PROJECT_BOARD.md`](../../docs/PROJECT_BOARD.md).
