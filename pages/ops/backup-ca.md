---
title: Back Up CA
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Back Up CA

The encrypted backup contains the step-ca configuration and runtime state, the
installed environment marker, and the local root CA under
`/var/lib/bmca/root-ca`. It is sufficient to restore the CA and retain
intermediate-rotation capability.

Create the backup passphrase once:

```sh
root@sally:~ # install -d -m 0700 /etc/bmca
root@sally:~ # sh -c 'umask 077; openssl rand -base64 48 > /etc/bmca/backup-passphrase'
root@sally:~ # test "$(stat -c '%a' /etc/bmca/backup-passphrase)" = 600
```

Create the encrypted development backup:

```sh
root@sally:~ # /opt/bmca/scripts/backup-ca.sh --env dev
[SUCCESS] Encrypted backup created: /imports/disk1/backups/bmca/dev/bmca-dev-REPLACE_WITH_TIMESTAMP.tar.gpg
```

Verify the newest backup:

```sh
root@sally:~ # BACKUP=$(find -H /opt/bmca/backups -maxdepth 1 -type f \
  -name 'bmca-dev-*.tar.gpg' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
root@sally:~ # test -n "$BACKUP"
root@sally:~ # cd "$(dirname "$BACKUP")"
root@sally:$(dirname "$BACKUP") # sha256sum -c "$(basename "$BACKUP").sha256"
```
