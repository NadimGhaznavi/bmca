---
title: Set Up CA
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Set Up CA

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
