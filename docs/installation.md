# Install the BMCA foundation

This greenfield checkpoint installs BMCA's identity package and lifecycle tools.
It does not install a working CA, create the planned MariaDB database, or provide
certificate issuance/deployment yet. XMR integration is excluded.

## Identity and roles

The canonical metadata file is `bmca/constants/DBMCA.py`. It declares literal
version/CMDB fields, `/opt/prod/bmca`, configuration under `conf`, persistent data
under `data`, and the planned `("BMCA", "bmca")` database reference. CMDB matches
that catalog only after it exists on the host. No database credentials or schema
are generated. Listener declarations remain empty at this checkpoint.

Select the role explicitly on first installation:

- `ca`: the future CA/application host, including its planned database and
  persistent configuration/data declarations.
- `target`: an identity/tooling foundation for certificate consumers. Its
  installed metadata omits CA paths, database references, and listeners.

Both roles install the Python identity package plus `install.py`, `install.sh`,
`upgrade.sh`, `uninstall.sh`, and `check-cmdb.py`. The existing shell CA/XMR tools,
old configuration files, systemd units, and certificate templates are not copied.
Python 3.10 or newer and Bash are required; there are no pip dependencies or venv
at this checkpoint. The installer verifies imports with `/usr/bin/python3`.

## Commands

Run from a separate source checkout. The following are operator examples; this
checkpoint has only been exercised in disposable directories.

```sh
python3 -B scripts/check-cmdb.py --name BMCA bmca/constants/DBMCA.py
scripts/install.sh --role ca --check
sudo scripts/install.sh --role ca
# On a certificate target, use --role target instead.
scripts/upgrade.sh --check
sudo scripts/upgrade.sh
scripts/uninstall.sh --check
sudo scripts/uninstall.sh
```

`--help` and `--check` do not require root or change files. The actual actions
under `/opt/prod/bmca` require root. A fresh install requires a role. Later actions
read `conf/installation.json`; attempts to change the installed role are rejected.

The successful installation contains:

```text
/opt/prod/bmca/
  bmca/constants/DBMCA.py
  scripts/...
  conf/installation.json
  .installation-manifest.json
  .deployment-version
```

The manifest inventories managed code. The role file and other configuration/data
are retained on uninstall. An empty ownership tombstone permits repeat uninstall
and reinstall without claiming unrelated files. Unexpected unowned installations
and symlinked deployment paths are refused.

The version marker is written last, after copied-file, executable, and installed
import verification. Failure does not advance it, but file replacement is not a
transactional rollback. Inspect or retry a failed operation from the source
checkout. Keep development paths and secrets out of the deployed payload.

No migration from `/opt/bmca`, NFS mount change, or archive relocation is performed.
