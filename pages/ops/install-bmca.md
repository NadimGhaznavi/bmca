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
./scripts/install-ca.sh --env dev
```

The installer always performs a clean installation. After confirmation, it stops the existing CA and permanently removes all prior BMCA and Smallstep configuration and state. Existing CA identity, keys, provisioners, database contents, and issued certificates are not preserved.

output:

```sh
[SUCCESS] Clean-installed bmca REPLACE_WITH_VERSION for dev. Run initialize-bmca.sh to create the CA.
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

Continue with [Set Up CA](/pages/ops/setup-ca), then regenerate and redeploy all project certificates.

BMCA currently supports `dev` on Sally and `prod` on Paris. Use the matching
environment in every command; scripts reject execution on the wrong host.

---

[Home](/index.html)
