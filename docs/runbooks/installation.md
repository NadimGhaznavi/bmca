# Installation and host preparation

Install development only on Sally with `--environment dev`. Install production
only on Paris with `--environment prod`. The installer verifies this mapping
and refuses to run on the wrong host.

## Shared release prerequisites

Both hosts deploy from a reviewed, annotated Git release tag checked out at
`/opt/dev/bmca`. Never install production from `main`, `dev`, or a feature
branch.

```sh
cd /opt/dev/bmca
git status --short
git describe --tags --exact-match
test -f scripts/lib/common.sh
bash tests/test-static.sh
/usr/bin/step version
/usr/bin/step-ca version
```

Stop if:

- `git status --short` reports local changes.
- `git describe --tags --exact-match` does not print the intended release tag.
- `scripts/lib/common.sh` is absent.
- Static tests fail.
- Installed Smallstep versions differ from `conf/settings.cfg`.

Do not repair an incomplete release by copying individual files between hosts.
Correct the Git release and deploy the replacement tag.

## Development installation — Sally

### 1. Confirm the development identity

```sh
hostname -s
host devca.osoyalce.com
source conf/settings.cfg
printf '%s\n' "$DEV_CA_HOST" "$DEV_CA_NAME" "$DEV_CA_ADDRESS"
```

Expected values:

```text
sally
devca.osoyalce.com
192.168.0.86
```

`devca.osoyalce.com` must resolve through `sally.osoyalce.com` to
`192.168.0.86`.

### 2. Verify the development backup destination

```sh
findmnt --target "$DEV_BACKUP_TARGET_DIR"
test -d "$DEV_BACKUP_TARGET_DIR"
test -w "$DEV_BACKUP_TARGET_DIR"
printf '%s\n' "$DEV_BACKUP_TARGET_DIR"
```

This NFS directory is for encrypted development archives only. Never place
`/var/lib/step-ca`, an offline-root workspace, or decrypted data there.

### 3. Install development

```sh
sudo scripts/install.sh --environment dev
test "$(cat /opt/bmca/conf/environment)" = dev
test "$(readlink /opt/bmca/backups)" = "$DEV_BACKUP_TARGET_DIR"
systemctl cat step-ca.service
```

For a new development CA, continue with the `dev` procedure in
[initialization](initialization.md). For recovery, continue with
[backup and restoration](backup-restore.md).

## Production installation — Paris

Do not begin production installation until the complete development lifecycle
has passed on Sally: installation, initialization/import, certificate issuance,
encrypted backup, restoration, and final validation.

### 1. Confirm the production identity and release

```sh
hostname -s
host ca.osoyalce.com
source conf/settings.cfg
printf '%s\n' "$PROD_CA_HOST" "$PROD_CA_NAME" "$PROD_CA_ADDRESS"
git describe --tags --exact-match
```

Expected values:

```text
paris
ca.osoyalce.com
192.168.0.27
```

`ca.osoyalce.com` must resolve through `paris.osoyalce.com` to `192.168.0.27`.
Confirm again that the checked-out tag is the approved production release.

### 2. Verify the production backup destination

```sh
findmnt --target "$PROD_BACKUP_TARGET_DIR"
test -d "$PROD_BACKUP_TARGET_DIR"
test -w "$PROD_BACKUP_TARGET_DIR"
printf '%s\n' "$PROD_BACKUP_TARGET_DIR"
```

The production target must differ from the development target:

```sh
test "$PROD_BACKUP_TARGET_DIR" != "$DEV_BACKUP_TARGET_DIR"
```

This NFS directory is for encrypted production archives only. The production
offline-root workspace must never be stored on Paris or NFS.

### 3. Install production

```sh
sudo scripts/install.sh --environment prod
test "$(cat /opt/bmca/conf/environment)" = prod
test "$(readlink /opt/bmca/backups)" = "$PROD_BACKUP_TARGET_DIR"
systemctl cat step-ca.service
```

For a new production CA, continue with the production ceremony in
[initialization](initialization.md). For recovery, continue with
[backup and restoration](backup-restore.md).

## What installation changes

For either environment, `install.sh`:

- Installs released scripts, settings, and the systemd source under
  `/opt/bmca`.
- Creates the unprivileged `step-ca` service account.
- Creates local configuration and state directories.
- Installs and reloads `step-ca.service`.
- Creates `/opt/bmca/backups` as a link to the selected NFS target.

It does not generate CA keys, initialize a new authority, overwrite existing CA
state, or start an uninitialized service.
