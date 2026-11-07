# Phased BMForge alignment

Refactor BMCA's internal design while preserving its observable behavior. Finish
one phase at a time, then stop for the user's review and Git commit. HTTP and new
certificate-management features follow the core alignment.

The governing BMForge snapshot is pinned in `.agents/bmforge/lock.json` at
`29a100c39997349ecfd40e190319aeb5018ffab8`. Installing the core skills does not
establish application conformance.

## Compatibility rules

- Canonical name: `BMCA`; package: `bmca`; metadata: `bmca/constants/DBMCA.py`.
- Preserve existing command options, English output, certificate semantics,
  configuration values and precedence, storage paths, and installation behavior.
- Keep Smallstep and the existing CA-host/certificate-target responsibilities.
- Inventory GUI labels (`dev`, `qa`, `prod`) do not imply separate backup
  destinations or different backup behavior. Preserve existing storage and mount
  arrangements. Clients use `/imports/...`; the NFS server uses local
  `/exports/...` paths. No storage migration is part of this refactor.
- Existing scripts also use `--env` to select CA hosts and settings. Reconcile
  that legacy behavior with inventory-only labels through discussion before
  changing it; this checkpoint leaves it intact.
- Discuss observable behavior changes before implementation. Record conflicts
  with BMForge as explicit gaps rather than silently changing the application.

## Checkpoints

| Phase | Scope | Acceptance |
| --- | --- | --- |
| 1. Foundation | Pin core skills, add project instructions and this plan, record changes, correct the invalid backup-separation test. | Static/CLI checks pass; integration skips are reported; runtime behavior is unchanged. |
| 2. Identity and configuration | Add domain-grouped constants and discoverable CMDB metadata; centralize existing settings. | Metadata checks pass and existing values, override behavior, and paths are preserved. |
| 3. Installation structure | Adapt the pinned installer and lifecycle entry points to the existing installation roles. | Disposable compatibility tests preserve existing payloads, paths, configuration, and lifecycle semantics. Discuss any new upgrade behavior or data-retention policy before implementing it. |
| 4. Application structure | Move shell orchestration into Python activities and interfaces, retaining existing command entry points. | Existing commands, certificate results, backup/restore behavior, and failure behavior pass regression checks. |
| 5. Localization structure | Introduce the pinned localizer, stable message keys, and English catalogue. | Existing English output and machine identifiers remain unchanged. Additional languages require separate requirements. |
| 6. Release and acceptance | Align metadata/release internals and complete cross-phase verification. | Exercise the existing release flow in a disposable repository; verify compatibility and document unresolved contract gaps. |
| Later | HTTP front end and additional certificate-management features. | Agree their behavior and acceptance criteria when those phases begin. |

Identity precedes installer restructuring so the installer can consume the
canonical metadata. The phases are review boundaries, not permission to change
operational behavior. Split a large phase into smaller checkpoints if needed.

## Phase 1 checkpoint

Ready for review and commit:

- Core skills, manager, and lock file are attached and uncommitted.
- Project instructions and this phased plan record the behavior-preservation
  rule and user-owned commit checkpoints.
- Both existing backup defaults remain `/imports/bmca`. The static test no longer
  incorrectly requires them to differ. No backup paths, mounts, or archives were
  changed, and the existing test runner is retained.
- `bash tests/test-all.sh`: static and CLI checks pass; initialization and
  encrypted-backup integration fixtures skip because this workspace is
  unprivileged. These skips do not establish live CA readiness.
- BMForge's offline check reports all installed pins current against the local
  source snapshot. The changelog records the skill attachment and foundation.

Known BMForge gaps remain: no standard upgrade command, installation ownership
manifest, or verified installed-version marker. Current installation deletes CA
state and uninstall removes the local root CA. Changing those semantics, or
moving `/opt/bmca` to `/opt/prod/bmca`, requires discussion before implementation.
The next phase is identity and configuration.
