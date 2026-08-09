# Encrypted backup and restoration

Backups contain the online intermediate key, SSH CA keys, database, CA
configuration, and service password. They never contain the offline X.509 root
private key. Encryption occurs on local disk before an archive is copied to
NFS.

## 1. Create the backup passphrase

This passphrase must differ from `/root/.bmca`:

```sh
sudo install -d -m 0700 /etc/bmca
sudo sh -c 'umask 077; openssl rand -base64 48 > /etc/bmca/backup-passphrase'
sudo test "$(stat -c '%a' /etc/bmca/backup-passphrase)" = 600
```

Keep a separate offline copy of this passphrase. Do not store it on NFS or in
Git. Losing it makes every encrypted backup unusable.

## 2. Create and verify a backup

```sh
sudo /opt/bmca/scripts/backup-ca.sh --environment dev
ls -l /opt/bmca/backups
BACKUP=$(find -H /opt/bmca/backups -maxdepth 1 -type f \
  -name 'bmca-dev-*.tar.gpg' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
test -n "$BACKUP"
sha256sum -c "$BACKUP.sha256"
```

The script briefly stops an active CA for consistency and restarts it on exit.
It uses a lock to prevent concurrent backups and refuses to proceed if it finds
an online `root_ca_key` or a non-writable destination.

## 3. Restore

Install the matching bmca release first. Ensure the backup passphrase is at
`/etc/bmca/backup-passphrase`, mode `0600`, then identify the exact archive:

```sh
BACKUP="REPLACE_WITH_ABSOLUTE_BACKUP_ARCHIVE_PATH"
test -f "$BACKUP"
sha256sum -c "$BACKUP.sha256"
sudo /opt/bmca/scripts/restore-ca.sh \
  --environment dev \
  --archive "$BACKUP"
```

The command requires confirmation and normally creates a safety backup of any
existing state. It validates the checksum, archive paths, required files,
absence of the root key, and certificate chain before replacing state. It then
starts and validates the service.

Use `--skip-safety-backup` only when local CA state is absent or irrecoverable:

```sh
sudo /opt/bmca/scripts/restore-ca.sh \
  --environment dev \
  --archive "$BACKUP" \
  --skip-safety-backup
```

After recovery, compare the root fingerprint with the offline ceremony
manifest, issue a short-lived test certificate, test XMR Pool web and MariaDB
TLS connections, and create a fresh backup. Revocation testing is not part of
the current project scope.
