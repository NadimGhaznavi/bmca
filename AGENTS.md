# BMCA project instructions

BMCA manages a Smallstep certificate authority and certificate-target tools.
The confirmed canonical application name is `BMCA`; the Python package is
`bmca`, with identity metadata in `bmca/constants/DBMCA.py` when introduced.
Smallstep remains the CA engine.

## Migration scope

- Follow `docs/bmforge-alignment.md`. Complete one phase, report its changes and
  verification, then stop for the user's checkpoint and Git commit. Continue
  when the user asks. Commits, pushes, releases, and deployments remain
  user-controlled.
- Internal design and structure may change. Preserve observable behavior:
  existing commands/options, output, certificate semantics, configuration
  values, backup layout, installation paths, and lifecycle behavior.
- Discuss behavior changes before implementing them. If a BMForge requirement
  conflicts with existing behavior, record the gap and discuss it; do not
  silently change behavior to claim compliance.
- `dev`, `qa`, and `prod` are inventory GUI labels. Do not introduce backup
  separation or storage policy based on those labels. Preserve current script
  behavior during refactoring; discuss any existing label-dependent operational
  behavior before changing it.
- Storage follows the existing mounts: clients use `/imports/...`; the NFS
  server uses corresponding local `/exports/...` paths. Do not invent a new
  directory layout or automatic host-selection mechanism.
- HTTP UI and additional certificate-management features are later phases.

## Engineering and verification

- Follow the pinned core skills under `.agents/skills/`. Before the first
  BMForge-derived edit in a session, run
  `python3 .agents/bmforge/manage.py check --project .`. Updates need approval.
- This is an established attached project. Do not run BMForge `init` or
  `setup-branches`, regenerate the application, or replace release history.
- Use activities for orchestration, interfaces for external systems, and
  entities only when meaningful. Keep composition simple and preserve existing
  external tools and dependencies.
- Update `CHANGELOG.md` under its single `Unreleased` heading for every completed
  logical change, with one current `Summary` for meaningful work.
- Run `bash tests/test-all.sh` plus focused compatibility checks appropriate to
  each phase. Use disposable fixtures for integration/lifecycle tests. Report
  root-dependent skips and distinguish fixture results from live-host checks.
- Implementation does not authorize operating a live CA, changing mounts,
  restarting host services, or deploying. Leave changes available for review.
