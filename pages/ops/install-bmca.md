---
title: Install BMCA
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Install BMCA

As **root**, clone the release into the configured source directory:

```sh
cd
git clone git@github.com:NadimGhaznavi/bmca
cd /root/bmca
```

Confirm the required programs and backup directory:

```sh
source conf/settings.cfg
"$STEP_CLI_BIN" version
"$STEP_CA_BIN" version
test -d "$DEV_BACKUP_TARGET_DIR"
```

Install development on Sally:

```sh
./scripts/install.sh --env dev
```

output:

```sh
[SUCCESS] Installed bmca REPLACE_WITH_VERSION for dev. Initialize or restore the complete CA before enabling the service.
```

Verify the installation:

```sh
test "$(cat /opt/bmca/conf/environment)" = dev
systemctl cat step-ca.service
systemctl is-enabled step-ca.service
```

Output:

```sh
disabled
```

Continue with [Set Up CA](/pages/ops/setup-ca) for a new CA or
[Restore CA](/pages/ops/restore-ca) when rebuilding the host.

When reinstalling BMCA with an existing CA in `/etc/step-ca` and
`/var/lib/step-ca`, the installer enables and starts `step-ca.service`
automatically.

BMCA currently supports `dev` on Sally and `prod` on Paris. Use the matching
environment in every command; scripts reject execution on the wrong host.

---

[Home](/index.html)
