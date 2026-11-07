# Lifecycle and failure-path verification

Run the current greenfield acceptance suite with:

```sh
bash tests/test-all.sh
```

Tests use disposable source/install directories and local bare Git remotes. They
do not operate a live CA, database, NFS mount, system service, or project remote.
No root access is required for these fixtures.

## Coverage

| Area | Verified behavior |
| --- | --- |
| Both installation roles | Install, repeat install, upgrade, uninstall, repeat uninstall, and reinstall; role retention and retained configuration/data. |
| Read-only checks | Install/upgrade/uninstall checks leave source/install snapshots unchanged; missing prerequisites fail before mutation in both check and real modes. |
| Ownership boundaries | Reject malformed/foreign/traversal manifests, invalid roles, managed symlinks, source symlinks, overlapping paths, and new code that would overwrite unowned files. The retained role record cannot be claimed as managed code. |
| Partial operations | An interrupted copy retains ownership information and the last-successful version; retry succeeds. Failed atomic replacement retains the original file and cleans its temporary candidate. Obsolete owned files are removed without removing user files. |
| Optional dependencies | Real venv creation and offline wheel installation, dependency upgrade, failed pip install, retry, retained version marker after failure, and owned-venv cleanup. Missing, damaged, and non-runnable runtimes fail preflight; unowned environments are neither adopted nor removed. |
| Runtime isolation | The installed application and CLI work with the checkout unavailable; the fixture dependency imports from the production venv. Final payload verification uses the configured runtime. |
| CLI failures | Privilege errors happen before constructing the application. Filesystem/subprocess/timeout failures return failure without printing a success result. English catalogue and future-locale acceptance checks remain covered. |
| Release failures | Unchanged trees, empty/reverted changes, dirty work, metadata drift, invalid changelog, missing ancestry, and noninteractive publication are rejected. A remote hook rejecting only the tag proves atomic push leaves every remote ref unchanged. |

Dependency fixtures create a small local wheel and set pip to use only that local
wheel directory, with package indexes disabled. They do not add production
requirements: `DInstallation.REQUIREMENTS_FILE` remains `None` in this project.
The dependency-enabled configuration is tested through the deployment API and
explicit installed-venv CLI invocation; service/launcher dependency activation
belongs to the later feature that introduces actual requirements.

## Corrections demonstrated by regression tests

1. Reserve `conf/installation.json` alongside the manifest and version marker so
   uninstall cannot delete the retained role record through a malformed manifest.
2. Require a valid manifest role, including for an empty ownership tombstone.
3. Run final payload/import/catalogue verification with the owned venv interpreter
   when dependencies are configured, instead of using system Python.
4. Execute an existing owned venv interpreter during preflight and check its
   prefix and minimum Python version, rejecting a non-runnable runtime before
   copying files or changing installation records.

Each correction was preceded by a failing regression fixture. The fixes reuse
existing installer boundaries and localized error keys.

## Limits and recovery

The current build is an identity and lifecycle foundation. These tests do not
certify CA provisioning, certificate issuance, systemd health, MariaDB schemas,
database transactions, or real-host readiness. Those features still need their
own agreed behavior and disposable integration fixtures when implemented.

File deployment is not a transactional rollback: an interrupted upgrade can
leave replaced files while `.deployment-version` retains the last successful
version. Inspect the failure and retry or uninstall using the ownership record.
Likewise, a rejected atomic Git push leaves remote refs unchanged but can leave
local release commits and a tag. Inspect Git state before retrying publication.
