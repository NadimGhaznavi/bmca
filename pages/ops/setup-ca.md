---
title: Set Up CA
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Set Up CA

## Single-host lab setup

For the normal BMCA lab workflow, create the password and initialize the CA
directly on its host. Install BMCA first, and use a workspace path that does
not already exist:

```sh
root@paris:~ # umask 077
root@paris:~ # openssl rand -base64 48 > /root/.bmca
root@paris:~ # /opt/bmca/scripts/initialize-ca.sh local \
  --environment prod \
  --workspace /root/bmca-prod-root
```

This one command creates and configures the CA, installs `ca.json` and the
intermediate password as `/etc/step-ca/ca.json` and
`/etc/step-ca/intermediate-password`, installs the runtime state in
`/var/lib/step-ca`, enables and starts `step-ca.service`, and validates its
health. The workspace contains the root private key; retain it with mode
`0700`. It is deliberately not included in online CA backups.

Use `--environment dev --workspace /root/bmca-dev-root` on Sally.

Verify the resulting installation:

```sh
root@paris:~ # test -f /etc/step-ca/ca.json
root@paris:~ # test -f /etc/step-ca/intermediate-password
root@paris:~ # systemctl is-enabled step-ca.service
enabled
root@paris:~ # /opt/bmca/scripts/validate-ca.sh --environment prod
[SUCCESS] prod CA validation passed.
```

The command refuses to overwrite an existing workspace or installed CA. To
start over, uninstall BMCA, remove the preserved `/etc/step-ca` and
`/var/lib/step-ca` directories and the chosen root workspace, reinstall BMCA,
then run the command again.

## Offline-root setup

Create the CA password on the offline system:

```sh
root@offline:~ # umask 077
root@offline:~ # openssl rand -base64 48 > /root/.bmca
root@offline:~ # test "$(stat -c '%a' /root/.bmca)" = 600
```

Create the development CA and BMCA certificate profiles:

```sh
root@offline:~/bmca # ./scripts/initialize-ca.sh offline \
  --environment dev \
  --workspace /secure/offline/bmca-dev
```

Confirm the online bundle does not contain the root key:

```sh
root@offline:~/bmca # tar -tf /secure/offline/bmca-dev-online-dev.tar | grep root_ca_key && exit 1 || true
root@offline:~/bmca # cd /secure/offline
root@offline:/secure/offline # sha256sum -c bmca-dev-online-dev.tar.sha256
```

Transfer `bmca-dev-online-dev.tar` to Sally. Transfer `/root/.bmca` separately.
Then import the bundle:

```sh
root@sally:~ # cd /opt/bmca
root@sally:/opt/bmca # ./scripts/initialize-ca.sh import \
  --environment dev \
  --bundle /root/bmca-dev-online-dev.tar
```

Expected result:

```text
[SUCCESS] dev CA validation passed.
[SUCCESS] Imported, started, and validated the dev CA. The X.509 root key remains offline.
```
