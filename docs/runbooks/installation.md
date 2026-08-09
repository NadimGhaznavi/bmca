# Installation and host preparation

Use `dev` only on Sally and `prod` only on Paris. Deploy from an reviewed Git
release tag checked out at `/opt/dev/bmca`; do not deploy a feature branch.

## 1. Verify the host and release

```sh
hostname -s
cd /opt/dev/bmca
git describe --tags --exact-match
bash tests/test-static.sh
/usr/bin/step version
/usr/bin/step-ca version
```

Expected Smallstep versions are recorded in `conf/settings.cfg`. Confirm the
selected environment's CA name, address, and backup target there before
continuing.

## 2. Verify the backup target

For development:

```sh
source conf/settings.cfg
findmnt --target "$DEV_BACKUP_TARGET_DIR"
test -d "$DEV_BACKUP_TARGET_DIR"
test -w "$DEV_BACKUP_TARGET_DIR"
```

Use `PROD_BACKUP_TARGET_DIR` on Paris. This location stores encrypted archives
only; it must never be used for `/var/lib/step-ca`.

## 3. Install

```sh
sudo scripts/install.sh --environment dev
readlink /opt/bmca/backups
cat /opt/bmca/conf/environment
systemctl cat step-ca.service
```

The installer creates the `step-ca` service account, local state directories,
root-only bmca configuration directory, systemd unit, and environment-specific
backup symlink. It does not initialize keys or start an uninitialized CA.

Proceed to [initialization](initialization.md) for a new authority or
[backup and restoration](backup-restore.md) when recovering an existing one.
