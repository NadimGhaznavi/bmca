# BMCA project instructions

Build the new BMCA system as greenfield using the pinned BMForge core skills.
The canonical name is `BMCA`, package `bmca`, and identity file
`bmca/constants/DBMCA.py`. The installation root is `/opt/prod/bmca`.

## Scope and checkpoints

- Follow `docs/bmforge-alignment.md`. Complete one phase, report its changes and
  verification, and stop for the user's review and Git commit. Continue when
  asked. Commits, pushes, releases, and deployments remain user-controlled.
- Keep the design simple. Use the canonical templates directly; do not build
  compatibility bridges or import business behavior from the old application.
- The active foundation consists of `bmca/`, the canonical lifecycle scripts,
  the CMDB checker, and `tests/test_installation.py`. Legacy shell operations and
  configuration remain source references and are excluded from the new payload.
- Do not port XMR pool integration. It will be designed again from scratch in a
  later phase. The planned `bmca` MariaDB database belongs to BMCA itself.
- `dev`, `qa`, and `prod` are inventory GUI labels, not storage policies. Preserve
  the actual mount arrangement: clients use `/imports/...`, and the NFS server
  uses the corresponding `/exports/...` paths. No new backup layout is approved.
- HTTP UI, database provisioning/schema, and additional certificate-management
  features are later work. Discuss behavior requirements before adding them.

## Engineering and verification

- Before the first BMForge-derived edit in a session, run
  `python3 .agents/bmforge/manage.py check --project .`. Updates need approval.
- Use activities for orchestration, interfaces for external systems, and
  entities only when meaningful. Use ordinary composition, selected component
  templates, and only dependencies required by the current phase.
- Declare literal CMDB metadata, planned database references, and only listeners
  actually owned by the new implementation. Declarations do not provision them.
- Update `CHANGELOG.md` under its single `Unreleased` heading for every completed
  change, with one current `Summary` for meaningful work.
- Run `bash tests/test-all.sh` and focused checks. Exercise installation and
  failure cases in disposable directories. A package install is not proof that
  CA services or databases exist or are ready.
- Implementation does not authorize operating a live CA, changing mounts,
  restarting host services, creating databases, or deploying on real hosts.
- Preserve published Git/release history. Do not reinitialize the repository or
  run branch setup; the user already manages branches and commits.
