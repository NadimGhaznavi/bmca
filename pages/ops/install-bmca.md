---
title: Install BMCA
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Install BMCA

Clone the release into the configured source directory:

```sh
root@sally:~ # git clone git@github.com:NadimGhaznavi/bmca
root@sally:~ # cd /root/bmca
```

Confirm the required programs and backup directory:

```sh
root@sally:~/bmca # source conf/settings.cfg
root@sally:~/bmca # "$STEP_CLI_BIN" version
root@sally:~/bmca # "$STEP_CA_BIN" version
root@sally:~/bmca # test -d "$DEV_BACKUP_TARGET_DIR"
```

Install development on Sally:

```sh
root@sally:~/bmca # ./scripts/install.sh --environment dev
[SUCCESS] Installed bmca 0.2.38 for dev. Initialize or restore the CA before enabling the service.
```

Verify the installation:

```sh
root@sally:~/bmca # test "$(cat /opt/bmca/conf/environment)" = dev
root@sally:~/bmca # systemctl cat step-ca.service
```

Continue with [Set Up CA](/pages/ops/setup-ca) for a new CA or
[Restore CA](/pages/ops/restore-ca) when rebuilding the host.

When reinstalling BMCA with an existing CA in `/etc/step-ca` and
`/var/lib/step-ca`, the installer enables and starts `step-ca.service`
automatically.
