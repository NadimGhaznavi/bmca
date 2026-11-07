# Release BMCA

`scripts/new-release.sh` is adapted from the pinned BMForge release template.
It reads canonical metadata from `bmca/constants/DBMCA.py`; the legacy
`conf/settings.cfg` is not a release input.

## Prepare and publish

Commit the completed work on a feature branch and keep local `main` and `dev`
up to date. `main` must be an ancestor of `dev`, and `dev` an ancestor of the
feature branch. The user chooses the version and codename.

Every completed change belongs under the single `## [Unreleased]` heading in
`CHANGELOG.md`. Keep one current `### Summary` for meaningful work. The release
script promotes those entries; it does not write their explanation.

```sh
scripts/new-release.sh --help
scripts/new-release.sh 1.0.2 "Release codename"
# Optional explicit next local feature branch:
scripts/new-release.sh 1.0.2 "Release codename" feat/next-feature
```

Use a version without a leading `v`. Without the third argument, the next local
branch is `feat/maint-<version with patch incremented>`. The script requires
Bash, Git, Python, the committed metadata checker, and the three executable
lifecycle wrappers. It checks canonical CMDB metadata and any static
`[project].version` in `pyproject.toml` before proceeding.

After local checks it fetches `origin`, checks remote refs and ancestry, and
shows the release summary. Publication requires confirmation in an interactive
terminal. After confirmation it:

1. Merges the feature branch into `dev` with a merge commit.
2. Updates literal `VERSION` and `CMDB_CODENAME`, any static package version, and
   the changelog, then commits the release metadata.
3. Merges `dev` into `main` and creates an annotated `v<version>` tag.
4. Advances `dev` to `main` and atomically pushes `main`, `dev`, and the tag.
5. Creates the next local feature branch; that branch is not pushed.

This publishes Git refs. Installation and deployment remain separate actions;
an existing push-to-main workflow may publish documentation.

## Refuse an unchanged release

Before fetching, prompting, merging, or generating release metadata, the script
uses Git to compare the feature branch's committed files with local `main`:

```sh
git diff --quiet --no-ext-diff --no-textconv refs/heads/main HEAD --
```

An identical tree is refused. Empty commits, fully reverted changes, and an
immediate second release without new file changes do not qualify. New version
numbers or release-generated changelog entries cannot manufacture a difference
because those writes occur only after this check.

Any committed tracked-file difference counts, including documentation,
configuration, additions, deletions, renames, and file-mode changes. This guard
does not infer whether a change is important enough to release; that remains the
owner's decision. Uncommitted files must first be committed or stashed.

## Verification and recovery

Tests use disposable repositories and local bare remotes, including actual
interactive confirmation. They verify metadata and optional package-version
synchronization, annotated tags, matching branch tips, preserved changelog
history, cancellation, and rejection of unchanged or invalid releases.
An update hook that rejects only the tag also verifies that atomic publication
leaves the remote `main`, `dev`, and tag refs unchanged as a group. The tests
check the remaining local commits/tag and stopped workflow for recovery.

After publication, verify the tag, released metadata, matching `main`/`dev` tips,
and clean next feature branch. A failed operation can leave local merges or
metadata commits; inspect Git state before retrying. Atomic push protects the
requested remote refs as a group, not the preceding local operations. Cancelling
after the fetch can still leave refreshed remote-tracking refs.

Release tests establish tooling behavior, not readiness of the future CA service
or planned MariaDB database. Both remain later implementation work.
