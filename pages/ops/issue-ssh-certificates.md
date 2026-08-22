---
title: Issue SSH Certificates
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Issue SSH Certificates

Choose a host or user certificate, an absolute output path, and at least one
principal. The output directory must already exist and the key path must not:

```sh
root@sally:~ # test -f /root/.bmca-leaf || \
  sh -c 'umask 077; openssl rand -base64 48 > /root/.bmca-leaf'
root@sally:~ # install -d -m 0700 /var/lib/bmca/issued/ssh
root@sally:~ # /opt/bmca/scripts/issue-ssh.sh \
  --environment dev \
  --type host \
  --key-id app01 \
  --key-file /var/lib/bmca/issued/ssh/app01 \
  --principal app01.osoyalce.com \
  --provisioner-password-file /root/.bmca \
  --key-password-file /root/.bmca-leaf
```

Use `--type user` for a user certificate. Repeat `--principal` when needed and
optionally pass `--lifetime`. The script uses the configured defaults when no
lifetime is supplied. The generated private key remains encrypted with the
key-password file.
