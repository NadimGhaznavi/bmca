---
title: Restore CA
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Restore CA

Install BMCA first. Restore the backup passphrase to mode `0600`, then select
the backup:

```sh
root@sally:~ # test "$(stat -c '%a' /etc/bmca/backup-passphrase)" = 600
root@sally:~ # BACKUP=$(find -H /opt/bmca/backups -maxdepth 1 -type f \
  -name 'bmca-dev-*.tar.gpg' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
root@sally:~ # test -n "$BACKUP"
```

Restore the CA:

```sh
root@sally:~ # /opt/bmca/scripts/restore-ca.sh \
  --env dev \
  --archive "$BACKUP"
Restore REPLACE_WITH_BACKUP onto sally? Current CA state will be replaced. [y/N] y
[SUCCESS] dev CA validation passed.
[SUCCESS] Restored dev CA from REPLACE_WITH_BACKUP
```

The backup restores `/var/lib/bmca/root-ca` together with the complete step-ca
runtime state.

Verify the service:

```sh
root@sally:~ # systemctl is-active step-ca.service
active
root@sally:~ # systemctl is-enabled step-ca.service
enabled
root@sally:~ # /opt/bmca/scripts/validate-ca.sh --env dev
[SUCCESS] dev CA validation passed.
```
