# Bear & Moose CA

`bmca` installs and operates a small private Certificate Authority built on
Smallstep. Development runs on `sally` as `devca.osoyalce.com`; production runs
on `paris` as `ca.osoyalce.com`.

The design keeps the X.509 root private key offline. The online hosts contain
the intermediate key and separate SSH host/user CA keys. Live state is local;
NFS stores encrypted backup archives only.

## Documentation

Start with the [documentation roadmap](docs/README.md). It separates design and
trust decisions from ordered operator runbooks and provides reading paths for
development, production, routine operation, and recovery.

Design documents explain why the CA is structured this way:

- [Architecture and trust boundaries](docs/design/architecture.md)
- [Certificate issuance policy](docs/design/issuance-policy.md)

Operator runbooks provide commands in lifecycle order:

1. [Installation and host preparation](docs/runbooks/installation.md)
2. [Initial CA ceremony](docs/runbooks/initialization.md)
3. [Certificate issuance](docs/runbooks/certificate-issuance.md)
4. [Intermediate CA rotation](docs/runbooks/intermediate-rotation.md)
5. [Encrypted backup and restoration](docs/runbooks/backup-restore.md)
6. [Validation and uninstall](docs/runbooks/operations.md)
7. [Git release procedure](docs/runbooks/release.md)
8. [Test suite](docs/runbooks/testing.md)

Initialization defaults to the root-only password file `/root/.bmca`, which
must have mode `0600`. Backup encryption uses a different configured password.
Never commit populated CA state, passwords, private keys, decrypted backups,
or ceremony workspaces.
