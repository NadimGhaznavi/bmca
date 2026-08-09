# Test suite

Run the complete safe suite from the source checkout:

```sh
cd /opt/dev/bmca
tests/test-all.sh
```

The suite contains:

- `test-static.sh`: syntax, required settings, environment separation, paths,
  executable modes, systemd/config agreement, and private-key marker checks.
- `test-cli.sh`: safe `--help` behavior and rejection of invalid environments.
- `test-offline-init.sh`: disposable root/intermediate/SSH generation, exact
  online-bundle filtering, path rewriting, manifests, checksums, intermediate
  signing, CSR tamper rejection, and environment mismatch rejection.
- `test-backup.sh`: isolated GnuPG backup creation, checksum verification,
  archive-content checks, root-key exclusion, and absence of plaintext archives.

The backup integration test requires root and reports a skip otherwise. All of
its paths are below a unique `/tmp/bmca-backup-test.*` directory; it does not
touch the installed CA or NFS.

Run that isolated test explicitly with root privileges when it was skipped:

```sh
sudo tests/test-backup.sh
```

Before a production release, also exercise the documented development
lifecycle on Sally: install, initialize/import when rebuilding, validation,
issuance of disposable web and MariaDB certificates, encrypted NFS backup, and
restore with a sentinel file. Never run that destructive lifecycle test on
Paris.
