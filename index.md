---
layout: home
author_profile: true
---


`bmca` installs and operates a small private Certificate Authority built on
Smallstep. Development runs on `sally` as `devca.osoyalce.com`; production runs
on `paris` as `ca.osoyalce.com`.

The design keeps the X.509 root private key offline. The online hosts contain
the intermediate key and separate SSH host/user CA keys. Live state is local;
NFS stores encrypted backup archives only.

Additional documentation is available [here](/pages/index.html).

