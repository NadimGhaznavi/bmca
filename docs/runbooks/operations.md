# Validation and uninstall

## Routine validation

Run after installation, initialization, restoration, intermediate replacement,
or service/configuration changes:

```sh
sudo /opt/bmca/scripts/validate-ca.sh --environment dev
```

The validator checks the host/environment match, installed binaries, absence
of the X.509 root private key, required X.509 and SSH key material, intermediate
chain, systemd service, and HTTPS health endpoint. Use `prod` only on Paris.
The HTTPS check retries connection refusal for the bounded interval configured
in `settings.cfg`, allowing `step-ca` to finish startup after restoration.

Useful supporting checks:

```sh
systemctl status step-ca.service
journalctl -u step-ca.service --since today
openssl x509 -in /var/lib/step-ca/certs/intermediate_ca.crt \
  -noout -subject -issuer -serial -dates -fingerprint -sha256
```

## Uninstall

Create and verify an encrypted backup first. Then run:

```sh
sudo /opt/bmca/scripts/uninstall.sh
```

The command requires interactive confirmation. It stops/disables the service,
removes `/opt/bmca`, its backup symlink, and the systemd unit. It deliberately
preserves `/etc/step-ca` and `/var/lib/step-ca`, including online private keys.
Erasing preserved CA state is a separate, manual decommissioning ceremony and
is not implemented by this project.
