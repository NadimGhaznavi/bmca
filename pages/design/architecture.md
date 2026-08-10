# Architecture

The development authority is `devca.osoyalce.com`, a CNAME for
`sally.osoyalce.com` (`192.168.0.86`). The production authority is
`ca.osoyalce.com`, a CNAME for `paris.osoyalce.com` (`192.168.0.27`). Their
roots, intermediates, SSH keys, provisioners, state, and backups are distinct.

Both CA hosts run Debian 13 with Smallstep CLI 0.30.6 and `step-ca` 0.30.2.

The Git release is installed under `/opt/bmca`; its public settings are under
`/opt/bmca/conf`. Smallstep's CA configuration and service password are under
`/etc/step-ca`; mutable state and online keys are under `/var/lib/step-ca`.
The X.509 root key exists only in the offline ceremony workspace. The service
runs as the unprivileged `step-ca` account.

The operator source password `/root/.bmca` is `root:root` mode `0600`. Its
service copy `/etc/step-ca/intermediate-password` is `root:step-ca` mode `0640`
so `step-ca` can read it without making it generally accessible.

`/opt/bmca/backups` links to the environment-specific NFS directory. Backup
archives are encrypted locally with GnuPG before being copied there. The CA
never operates from NFS.

Intermediate replacement keys and CSRs are generated online. Only the CSR
crosses into the offline root environment, and only the signed intermediate
certificate returns. The root system is therefore a signing environment, not
a cold standby.

The current application scope is the XMR Pool web endpoint and its MariaDB TLS
connections, plus administrator MariaDB clients. SSH host and user CA keys are
kept separate for future/host access use. Revocation automation is explicitly
deferred; short lifetimes and replacement before expiry are the current
operational controls.

Git development and release preparation occur in `/opt/dev/bmca`. Annotated
release tags are deployed into `/opt/bmca`; Paris should never deploy directly
from a feature branch.
