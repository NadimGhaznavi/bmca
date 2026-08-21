---
title: Uninstall BMCA
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Uninstall BMCA

Run the installed uninstall script as root:

```sh
root@sally:~ # /opt/bmca/scripts/uninstall.sh
Stop BMCA and remove its installed files, configuration, and local work state? [y/N] y
[SUCCESS] Uninstalled bmca. Preserved Smallstep programs and CA state in /etc/step-ca and /var/lib/step-ca.
root@sally:~ #
```

The command stops and disables `step-ca.service`, then removes:

```text
/opt/bmca
/etc/bmca
/var/lib/bmca
/etc/systemd/system/step-ca.service
```

It does not remove:

```text
/usr/bin/step
/usr/bin/step-ca
/etc/step-ca
/var/lib/step-ca
/root/.bmca
```

Database services, database files, offline CA workspaces, and backup archives
are not changed.

Confirm the BMCA environment was removed:

```sh
root@sally:~ # systemctl status step-ca.service
Unit step-ca.service could not be found.
root@sally:~ # test ! -e /opt/bmca
root@sally:~ # test ! -e /etc/bmca
root@sally:~ # test ! -e /var/lib/bmca
root@sally:~ # test -d /etc/step-ca
root@sally:~ # test -d /var/lib/step-ca
```

To reinstall BMCA, clone or update the release checkout and run
`scripts/install.sh`. If an existing BMCA installation is present, the installer
stops `step-ca`, replaces the managed files, reloads systemd, and restores the
service to its previous running state.
