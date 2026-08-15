---
Title: Docs
author_profile: true
Layout: Default
---

# Bear & Moose CA documentation roadmap

This is the starting point for designing, deploying, and operating bmca. Read
the design documents first, then follow the operational runbooks in lifecycle
order. Development procedures run on Sally using `dev`; production procedures
run on Paris using `prod`.

## Design and trust model

These documents explain the decisions that operators must understand before
creating keys or changing policy:

1. [Architecture and trust boundaries](design/architecture.md)
   - Development and production separation
   - Offline X.509 root versus online intermediate
   - Local live state versus encrypted NFS backups
   - Filesystem, service-account, and deployment boundaries
2. [Certificate issuance policy](design/issuance-policy.md)
   - Approved XMR Pool web and MariaDB certificate types
   - SSH host/user CA separation
   - Identity, lifetime, and authorization expectations
   - Current consequences of deferring revocation

## Operational lifecycle

Follow these runbooks in order for a new environment:

1. [Installation and host preparation](runbooks/installation.md)
   - Verify the Git release, pinned software, hostname, and NFS destination
   - Install bmca under `/opt/bmca`
   - Create the service account, local state paths, and systemd unit
2. [Initial CA ceremony](runbooks/initialization.md)
   - Generate the offline root and initial online authority material
   - Verify the root fingerprint and filtered transfer bundle
   - Import only online keys and start the CA
3. [Certificate issuance](runbooks/certificate-issuance.md)
   - Issue and deploy XMR Pool web TLS certificates
   - Issue MariaDB server and application mTLS certificates
   - Issue administrator MariaDB client certificates
4. [Encrypted backup and restoration](runbooks/backup-restore.md)
   - Create the independent backup passphrase
   - Produce and verify encrypted NFS backups
   - Restore state safely and validate the recovered CA
5. [Routine validation and uninstall](runbooks/operations.md)
   - Check certificate chains, key separation, service state, and HTTPS health
   - Remove installed software while preserving CA state

Use these runbooks when their corresponding lifecycle event occurs:

- [Intermediate CA rotation](runbooks/intermediate-rotation.md): planned
  intermediate renewal using an online CSR and offline root signature.
- [Git release procedure](runbooks/release.md): publish an immutable version
  before deployment to Sally or Paris.
- [Test suite](runbooks/testing.md): run safe automated tests and the explicit
  Sally development lifecycle exercise before production releases.

## Suggested reading paths

### First development deployment

Read architecture, issuance policy, installation, initialization, testing,
certificate issuance, and backup/restore—in that order. Complete the entire
workflow on Sally before preparing production.

### Production deployment

Review both design documents, testing results, installation, and the complete
initialization ceremony. Deploy only an annotated Git release tag. Keep the
production root workspace off Sally, Paris, Git, and NFS.

### Routine operator

Use certificate issuance, operations, and backup/restore. Escalate planned
intermediate renewal to an operator with custody of the offline root.

### Recovery operator

Read architecture and backup/restore before changing state. Confirm the target
environment, root fingerprint, archive checksum, and backup-passphrase custody.

## Current project scope

The current lifecycle supports:

- XMR Pool web TLS
- MariaDB server TLS and application/admin mTLS clients
- Separate SSH host and user CA keys
- Offline-root initialization and planned intermediate renewal
- Installation, validation, encrypted backup, restoration, and uninstall

Automated revocation and automated root rollover are intentionally deferred.
An intermediate-key compromise therefore requires a separately planned new
root hierarchy and trust-anchor rollout; ordinary intermediate rotation is not
sufficient.
