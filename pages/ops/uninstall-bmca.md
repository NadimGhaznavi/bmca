---
title: Uninstall BMCA
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Uninstall BMCA

Run the installed uninstall script:

```sh
root@sally:~ # /opt/bmca/scripts/uninstall.sh
Stop BMCA and remove its installed files, configuration, and local work state? [y/N] y
[SUCCESS] Uninstalled bmca. Preserved Smallstep programs and CA state in /etc/step-ca and /var/lib/step-ca.
```

Verify BMCA was removed and the CA state was preserved:

```sh
root@sally:~ # test ! -e /opt/bmca
root@sally:~ # test ! -e /etc/bmca
root@sally:~ # test ! -e /var/lib/bmca
root@sally:~ # test -d /etc/step-ca
root@sally:~ # test -d /var/lib/step-ca
```

The local root CA under `/var/lib/bmca/root-ca` is BMCA state, so uninstalling
BMCA removes it. The step-ca runtime state remains available for reinstall,
but intermediate rotation requires the local root CA. Copy that directory to
separate storage or create an encrypted BMCA backup before uninstalling if you
want to retain that ability.
