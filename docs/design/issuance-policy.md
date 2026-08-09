# Issuance policy

X.509 issuance is limited to XMR Pool web servers, MariaDB server identities,
MariaDB mTLS client identities, and named administrator clients. Server
certificates use DNS/IP SANs. Client certificates use stable person or service
identities. Private keys are never committed to Git.

SSH host and user certificates are signed by separate CA keys. Host principals
must be inventory names or approved DNS names. User principals must map to an
accountable person or automation identity. Short lifetimes are preferred;
renewal is an operational process, not a reason to issue long-lived leaves.

Use `issue-x509.sh` for the four approved X.509 kinds and `issue-ssh.sh` for
SSH host/user certificates. Both require password files outside Git, refuse to
overwrite keys, and apply the lifetimes in `conf/settings.cfg` unless an
operator supplies a shorter approved duration.

Detailed commands and deployment checks are in
[`certificate-issuance.md`](../runbooks/certificate-issuance.md).

Issuance identity, requested principals, expiry, and approving operator must be
recorded. Revocation handling is outside the current project scope. Development
trust anchors must never be installed as production trust anchors.

Because revocation is deferred, a compromised certificate remains
cryptographically valid until expiry. For a leaf compromise, replace the leaf
and disable or constrain the affected MariaDB/application identity. For an
intermediate compromise, merely rotating the intermediate is insufficient: a
new root hierarchy and trust-anchor rollout are required to distrust the old
intermediate before it expires.
