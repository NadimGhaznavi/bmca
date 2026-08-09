# Git release procedure

Prepare releases on Sally from a clean `feat/*` or `feature/*` branch. The
release script merges through `dev`, `release/vX.Y.Z`, and `main`; updates
`PROJECT_VERSION` and `CHANGELOG.md`; creates an annotated tag; atomically
pushes the release refs; and creates the requested next feature branch.

## 1. Preflight

```sh
cd /opt/dev/bmca
git status --short
bash tests/test-static.sh
bash tests/test-offline-init.sh
```

Review every tracked file for secrets and update the `[Unreleased]` section in
`CHANGELOG.md`. The script refuses dirty trees, duplicate refs, diverged
`main`/`dev`, tracked private-key markers, and likely password files.

## 2. Publish

```sh
scripts/new-release.sh \
  0.1.0 \
  "Bear & Moose CA 0.1.0" \
  feat/next-change
```

Replace all three example values. Review the interactive summary before
confirming. Deploy Sally or Paris from the resulting immutable tag, then run
the installation and validation runbooks.
