---
Title: Provide TLS certificates for MariaDB
author_profile: true
Layout: Default
---

![BMCA Logo](/pages/images/bmca-logo.png)

---

# Provide TLS certificates for MariaDB

Use this procedure to issue and deploy a MariaDB server certificate and an XMR
Pool client certificate. The result is an encrypted database connection in
which the application verifies the MariaDB server and MariaDB requires a
certificate from the application.

Run the issuance commands on the bmca host as root. Use `dev` on Sally and
`prod` on Paris. Complete the procedure in development before repeating it in
production.

Values beginning with `REPLACE_WITH_` are placeholders. Stop if any remain
before issuing certificates or changing MariaDB.

## 1. Confirm the request

Record the following before issuance:

- MariaDB DNS name used by clients. The server certificate SAN must match it.
- XMR Pool application host and MariaDB account.
- Requester and approving operator.
- Requested lifetime, or approval to use the default in `conf/settings.cfg`.

Do not use a development trust anchor or certificate in production.

## 2. Prepare the CA host

```sh
cd /opt/bmca
ENVIRONMENT="REPLACE_WITH_dev_OR_prod"
sudo scripts/validate-ca.sh --environment "$ENVIRONMENT"
sudo test "$(stat -c '%a' /root/.bmca)" = 600
sudo sh -c 'umask 077; openssl rand -base64 48 > /root/.bmca-leaf'
sudo test "$(stat -c '%a' /root/.bmca-leaf)" = 600
sudo install -d -m 0700 /root/bmca-issued
```

`/root/.bmca-leaf` protects the newly generated leaf private keys during
transfer. It must be different from the provisioner password in `/root/.bmca`.

## 3. Issue the MariaDB server certificate

Set `DB_NAME` to the DNS name applications use in their database connection.
Add another `--san` for each additional approved DNS name or IP address.

```sh
DB_NAME="REPLACE_WITH_MARIADB_DNS_NAME"
sudo scripts/issue-x509.sh \
  --environment "$ENVIRONMENT" \
  --kind mariadb-server \
  --subject "$DB_NAME" \
  --san "$DB_NAME" \
  --output-dir /root/bmca-issued/mariadb-server \
  --provisioner-password-file /root/.bmca \
  --key-password-file /root/.bmca-leaf
```

Inspect the identity, validity period, usages, and chain:

```sh
sudo openssl x509 \
  -in "/root/bmca-issued/mariadb-server/$DB_NAME.crt" \
  -noout -subject -issuer -dates -ext subjectAltName -ext extendedKeyUsage
sudo openssl verify \
  -CAfile /var/lib/step-ca/certs/root_ca.crt \
  -untrusted /var/lib/step-ca/certs/intermediate_ca.crt \
  "/root/bmca-issued/mariadb-server/$DB_NAME.crt"
```

The SAN output must contain every name clients will use, and verification must
return `OK`.

## 4. Issue the XMR Pool client certificate

Use the stable application identity `xmr-pool`; a client certificate does not
use a hostname SAN.

```sh
sudo scripts/issue-x509.sh \
  --environment "$ENVIRONMENT" \
  --kind mariadb-client \
  --subject xmr-pool \
  --output-dir /root/bmca-issued/mariadb-client \
  --provisioner-password-file /root/.bmca \
  --key-password-file /root/.bmca-leaf

sudo openssl x509 \
  -in /root/bmca-issued/mariadb-client/xmr-pool.crt \
  -noout -subject -issuer -dates -ext extendedKeyUsage
sudo openssl verify \
  -CAfile /var/lib/step-ca/certs/root_ca.crt \
  -untrusted /var/lib/step-ca/certs/intermediate_ca.crt \
  /root/bmca-issued/mariadb-client/xmr-pool.crt
```

## 5. Deploy the server identity

Transfer the server certificate and encrypted key, plus `root_ca.crt` and
`intermediate_ca.crt`, to the MariaDB host over an authenticated administrative
channel. Transfer `/root/.bmca-leaf` separately. On the MariaDB host, install
the files using paths and ownership readable by the MariaDB service:

```sh
DB_NAME="REPLACE_WITH_MARIADB_DNS_NAME"
sudo install -d -m 0750 -o mysql -g mysql /etc/mysql/tls
sudo openssl pkey -in "$DB_NAME.key" \
  -passin file:/root/.bmca-leaf -out /etc/mysql/tls/server.key
sudo install -m 0644 "$DB_NAME.crt" /etc/mysql/tls/server.crt
sudo install -m 0644 root_ca.crt /etc/mysql/tls/root_ca.crt
sudo install -m 0644 intermediate_ca.crt /etc/mysql/tls/intermediate_ca.crt
sudo chown mysql:mysql /etc/mysql/tls/server.key
sudo chmod 0600 /etc/mysql/tls/server.key
```

Configure MariaDB:

```ini
[mariadb]
ssl_ca=/etc/mysql/tls/root_ca.crt
ssl_cert=/etc/mysql/tls/server.crt
ssl_key=/etc/mysql/tls/server.key
require_secure_transport=ON
```

Restart MariaDB, then confirm that TLS and the configured paths are active:

```sql
SHOW VARIABLES WHERE Variable_name IN
  ('have_ssl', 'ssl_ca', 'ssl_cert', 'ssl_key', 'require_secure_transport');
```

## 6. Deploy the application identity

Transfer the XMR Pool certificate and encrypted key and `root_ca.crt` to the
application host through an authenticated administrative channel. Transfer
`/root/.bmca-leaf` separately. Install the decrypted key so only the XMR Pool
service account can read it:

```sh
sudo install -d -m 0750 -o xmrpool -g xmrpool /etc/xmrpool/tls
sudo openssl pkey -in xmr-pool.key \
  -passin file:/root/.bmca-leaf -out /etc/xmrpool/tls/mariadb-client.key
sudo install -m 0644 xmr-pool.crt /etc/xmrpool/tls/mariadb-client.crt
sudo install -m 0644 root_ca.crt /etc/xmrpool/tls/root_ca.crt
sudo chown xmrpool:xmrpool /etc/xmrpool/tls/mariadb-client.key
sudo chmod 0600 /etc/xmrpool/tls/mariadb-client.key
```

Configure the application to use these three files and the same DNS name that
appears in the server certificate. On MariaDB, require a client certificate for
the application account:

```sql
ALTER USER 'xmr_pool'@'REPLACE_WITH_APPLICATION_HOST' REQUIRE X509;
```

## 7. Verify the connection

From the application host, test mutual TLS with server-name verification:

```sh
DB_NAME="REPLACE_WITH_MARIADB_DNS_NAME"
mariadb --host="$DB_NAME" --ssl-verify-server-cert \
  --ssl-ca=/etc/xmrpool/tls/root_ca.crt \
  --ssl-cert=/etc/xmrpool/tls/mariadb-client.crt \
  --ssl-key=/etc/xmrpool/tls/mariadb-client.key
```

In the resulting session, confirm that TLS is in use:

```sql
SHOW SESSION STATUS LIKE 'Ssl_cipher';
```

The cipher value must be non-empty. Also confirm that a connection without the
client certificate is rejected for the `xmr_pool` account.

## 8. Complete the request

Record each certificate's serial number, expiration, and SHA-256 fingerprint:

```sh
CERTIFICATE="REPLACE_WITH_CERTIFICATE_PATH"
test -f "$CERTIFICATE"
openssl x509 -in "$CERTIFICATE" \
  -noout -serial -enddate -fingerprint -sha256
```

### Remove temporary transfer material

Do not begin cleanup until the MariaDB service has restarted successfully, the
application has completed an mTLS connection, and the certificate details
above have been recorded. The installed files under `/etc/mysql/tls` and
`/etc/xmrpool/tls` are live service files and must remain in place.

On the MariaDB host, first confirm that the installed files exist and that the
private key has restrictive permissions:

```sh
sudo test -s /etc/mysql/tls/server.crt
sudo test -s /etc/mysql/tls/server.key
sudo test -s /etc/mysql/tls/root_ca.crt
sudo test "$(stat -c '%a' /etc/mysql/tls/server.key)" = 600
```

Assuming the incoming files were placed in `/root/bmca-transfer`, remove only
those transfer copies and the transferred leaf-password file:

```sh
DB_NAME="REPLACE_WITH_MARIADB_DNS_NAME"
TRANSFER_DIR=/root/bmca-transfer
test "$DB_NAME" != REPLACE_WITH_MARIADB_DNS_NAME
sudo test "$TRANSFER_DIR" = /root/bmca-transfer
sudo rm -f -- \
  "$TRANSFER_DIR/$DB_NAME.crt" \
  "$TRANSFER_DIR/$DB_NAME.key" \
  "$TRANSFER_DIR/root_ca.crt" \
  "$TRANSFER_DIR/intermediate_ca.crt" \
  /root/.bmca-leaf
sudo rmdir -- "$TRANSFER_DIR"
```

`rmdir` intentionally fails if the transfer directory contains anything else;
inspect unexpected files instead of deleting the directory recursively.

On the XMR Pool application host, verify the installed application identity,
then remove its transfer copies:

```sh
sudo test -s /etc/xmrpool/tls/mariadb-client.crt
sudo test -s /etc/xmrpool/tls/mariadb-client.key
sudo test -s /etc/xmrpool/tls/root_ca.crt
sudo test "$(stat -c '%a' /etc/xmrpool/tls/mariadb-client.key)" = 600

TRANSFER_DIR=/root/bmca-transfer
sudo test "$TRANSFER_DIR" = /root/bmca-transfer
sudo rm -f -- \
  "$TRANSFER_DIR/xmr-pool.crt" \
  "$TRANSFER_DIR/xmr-pool.key" \
  "$TRANSFER_DIR/root_ca.crt" \
  /root/.bmca-leaf
sudo rmdir -- "$TRANSFER_DIR"
```

Finally, on the CA host, remove the temporary leaf-key password and issued
staging files after confirming that deployment records are complete:

```sh
DB_NAME="REPLACE_WITH_MARIADB_DNS_NAME"
test "$DB_NAME" != REPLACE_WITH_MARIADB_DNS_NAME
sudo rm -f -- \
  "/root/bmca-issued/mariadb-server/$DB_NAME.crt" \
  "/root/bmca-issued/mariadb-server/$DB_NAME.key" \
  /root/bmca-issued/mariadb-client/xmr-pool.crt \
  /root/bmca-issued/mariadb-client/xmr-pool.key \
  /root/.bmca-leaf
sudo rmdir -- \
  /root/bmca-issued/mariadb-server \
  /root/bmca-issued/mariadb-client
```

Keep `/root/.bmca`; it is the CA provisioner password, not temporary transfer
material. Never commit a private key or password file, and never copy one into
the documentation tree.

### Renew the certificates

Revocation is not implemented in this release. Before either certificate
expires, repeat this procedure using new, empty staging directories, for
example `/root/bmca-issued/mariadb-server-renewal` and
`/root/bmca-issued/mariadb-client-renewal`. Verify and deploy both replacements,
restart MariaDB and the application as needed, and repeat the mTLS test before
removing the previous installed files or the renewal staging copies. Record the
new serial numbers, expirations, and fingerprints so the active certificates
are unambiguous.

For administrator client certificates and additional issuance details, see the
[certificate issuance procedure](../runbooks/certificate-issuance.md).
