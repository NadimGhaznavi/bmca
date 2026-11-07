# Phased BMForge build

Build a clean BMCA implementation from the pinned BMForge specifications.
Complete one phase at a time, then stop for the user's review and Git commit.
The canonical name is `BMCA`; the package is `bmca`.

The installed core skills are pinned in `.agents/bmforge/lock.json` at
`29a100c39997349ecfd40e190319aeb5018ffab8`.

## Agreed scope

- This is greenfield. Use the canonical templates directly and keep the design
  simple. Legacy scripts/configuration are reference material, not dependencies
  or payload of the new implementation.
- Do not port XMR pool workflows, host lists, certificate bundles, or deployment
  settings. Reintroduce that integration from scratch in a later phase.
- Include the planned MariaDB catalog `bmca` in BMCA's CMDB declaration. Database
  provisioning, schemas, credentials, and runtime database access are later work.
- Inventory GUI labels (`dev`, `qa`, `prod`) do not imply distinct backup storage
  or behavior. The existing NFS/autofs arrangement remains unchanged.
- Existing repository history and published releases remain intact.

## Checkpoints

| Phase | Scope | Acceptance |
| --- | --- | --- |
| 1. Foundation | Core skills, project instructions, and phased plan. | Pinned references and review/commit checkpoints are documented. |
| 2. Canonical identity and installation records | Literal metadata, `/opt/prod/bmca`, standard file installer, ownership manifest, retained installation role, verified version marker. | Disposable tests verify both roles, failure handling, configuration/data retention, and independence from the checkout. No legacy/XMR payload is installed. |
| 3. Python architecture | Organize the working foundation into activities, interfaces, entities, and an application composition root. | Preserve deployment behavior and exercise the Python API and installed CLI without the checkout. |
| 4. CA lifecycle and certificate operations | Define and implement the new CA engine integration and required generic certificate-management use cases. | Agree behavior first; verify provisioning, startup/health, certificate semantics, failures, and retained state in disposable environments. |
| 5. Localization | Introduce the pinned localizer, stable message keys, and English catalogue for the application UI/CLI. | Validate keys/placeholders and locale handling without altering machine identifiers. |
| 6. Release and acceptance | Configure the canonical release template and complete system verification and operator documentation. | Test release flow in a disposable repository and report remaining live-host validation. |
| Later | HTTP front end, additional certificate management, and a fresh XMR integration if requested. | Agree requirements when each phase begins. |

## Phase 2 checkpoint

The new foundation installs only the `bmca` identity package and standard
installation/checking tools. The CA role records configuration/data paths and
the planned `bmca` database. The target role records no CA-owned paths, database,
or listeners. Neither role installs or starts a CA, provisions MariaDB, or
installs old certificate scripts. Listener declarations are empty until the new
implementation owns a service.

The installer is adapted from the pinned BMForge `0.1.3` template. It verifies
copied files, executable permissions, and a real import from the installed
package before advancing `.deployment-version`. Upgrade retains the recorded
role; uninstall removes managed code while retaining configuration/data and an
ownership tombstone. Installation is a file operation, not a transactional
rollback; a failed upgrade can leave replaced files while the successful-version
marker remains unchanged.

The current package version remains `1.0.1`; this phase does not publish a
release. Legacy `scripts/new-release.sh` is not the release path for the new
system. The canonical release integration is scheduled for phase 6.

See [Installation](installation.md) for the current payload and commands.

## Phase 3 checkpoint

The working installation use case now follows the Python architecture described
in [Architecture](architecture.md). `BMCA` composes a deployment activity with a
filesystem/interpreter interface. The activity returns an immutable plan/result
entity; CLI parsing and output live at the boundary. The shell wrappers remain
launchers and deployment behavior is preserved.

The acceptance suite exercises the refactored API, unchanged lifecycle behavior,
and CLI argument validation. It also runs the installed package and script entry
points with the source checkout unavailable. CA service/issuance behavior, HTTP,
database provisioning, and XMR integration remain deferred. This checkpoint is
ready for user review and commit after its checks pass.
