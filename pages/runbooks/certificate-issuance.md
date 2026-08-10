# Certificate issuance procedure

This runbook covers the XMR Pool web certificate, MariaDB server certificate,
MariaDB application-client certificate, and administrator client certificate.
Run issuance on the CA host as root. Examples use development; replace `dev`
with `prod` only after validating the production hostname and requested names.

Values beginning with `REPLACE_WITH_` are placeholders. Stop if any such value
remains before issuance or deployment.

## 1. Preflight

```sh
cd /opt/bmca
sudo scripts/validate-ca.sh --environment dev
sudo test "$(stat -c '%a' /root/.bmca)" = 600
```

Create a temporary password for encrypting newly generated leaf private keys.
This is deliberately different from `/root/.bmca`:

```sh
sudo sh -c 'umask 077; openssl rand -base64 48 > /root/.bmca-leaf'
sudo test "$(stat -c '%a' /root/.bmca-leaf)" = 600
sudo install -d -m 0700 /root/bmca-issued
```

Record the subject, SANs, certificate kind, requesting system, approving
operator, and requested lifetime before issuance.

The current Smallstep default leaf profile includes both `serverAuth` and
`clientAuth` extended key usages for every kind. The `--kind` value selects the
approved workflow and SAN requirements; it does not create an exclusive EKU
profile. Confirm both usages during the inspection steps below.

## 2. XMR Pool web certificate

Replace the example DNS name with the actual browser-facing XMR Pool name. Add
one `--san` for every DNS name or IP address clients use.

```sh
WEB_NAME="REPLACE_WITH_XMR_POOL_DNS_NAME"
sudo scripts/issue-x509.sh \
  --environment dev \
  --kind web-server \
  --subject "$WEB_NAME" \
  --san "$WEB_NAME" \
  --output-dir /root/bmca-issued/web \
  --provisioner-password-file /root/.bmca \
  --key-password-file /root/.bmca-leaf
```

Inspect the identity and validity before deployment:

```sh
sudo openssl x509 -in "/root/bmca-issued/web/$WEB_NAME.crt" \
  -noout -subject -issuer -dates -ext subjectAltName -ext extendedKeyUsage
sudo openssl verify \
  -CAfile /var/lib/step-ca/certs/root_ca.crt \
  -untrusted /var/lib/step-ca/certs/intermediate_ca.crt \
  "/root/bmca-issued/web/$WEB_NAME.crt"
```

Transfer the certificate, intermediate, root, and encrypted private key over an
authenticated administrative channel. On the web host, decrypt the service key
without printing it and then remove the transferred encrypted copy. In the
example, the encrypted key was copied as `$WEB_NAME.key.encrypted`, while
`/root/.bmca-leaf` was transferred separately and removed after decryption:

```sh
sudo openssl pkey -in "$WEB_NAME.key.encrypted" \
  -passin file:/root/.bmca-leaf -out /etc/xmrpool/tls/web.key
sudo install -m 0644 "$WEB_NAME.crt" /etc/xmrpool/tls/web.crt
sudo install -m 0644 intermediate_ca.crt /etc/xmrpool/tls/intermediate_ca.crt
sudo install -m 0644 root_ca.crt /etc/xmrpool/tls/root_ca.crt
sudo chmod 0600 /etc/xmrpool/tls/web.key
```

Configure the web server to present `web.crt` followed by
`intermediate_ca.crt`, use `web.key`, reload it, and verify externally:

```sh
openssl s_client -connect "$WEB_NAME:443" \
  -servername "$WEB_NAME" \
  -CAfile root_ca.crt -verify_return_error </dev/null
```

## 3. MariaDB server certificate

The SAN must match the hostname used in MariaDB client connections.

```sh
DB_NAME="REPLACE_WITH_MARIADB_DNS_NAME"
sudo scripts/issue-x509.sh \
  --environment dev \
  --kind mariadb-server \
  --subject "$DB_NAME" \
  --san "$DB_NAME" \
  --output-dir /root/bmca-issued/mariadb-server \
  --provisioner-password-file /root/.bmca \
  --key-password-file /root/.bmca-leaf
```

Verify it with the same `openssl x509` and `openssl verify` commands used for
the web certificate. Transfer and decrypt the key on the database host, then
install the files with ownership readable by MariaDB. Configure the server:

```ini
[mariadb]
ssl_ca=/etc/mysql/tls/root_ca.crt
ssl_cert=/etc/mysql/tls/server.crt
ssl_key=/etc/mysql/tls/server.key
require_secure_transport=ON
```

Restart MariaDB and confirm the effective paths:

```sql
SHOW VARIABLES WHERE Variable_name IN
  ('have_ssl', 'ssl_ca', 'ssl_cert', 'ssl_key', 'require_secure_transport');
```

## 4. XMR Pool MariaDB client certificate

Use a stable service identity rather than a hostname:

```sh
ADMIN_NAME="REPLACE_WITH_ADMINISTRATOR_ACCOUNT_NAME"
sudo scripts/issue-x509.sh \
  --environment dev \
  --kind mariadb-client \
  --subject xmr-pool \
  --output-dir /root/bmca-issued/mariadb-client \
  --provisioner-password-file /root/.bmca \
  --key-password-file /root/.bmca-leaf
```

Install the decrypted key and certificate so only the XMR Pool service account
can read the key. Configure its MariaDB client connection with the root CA,
client certificate, and client key. Require TLS for its database account:

```sql
ALTER USER 'xmr_pool'@'REPLACE_WITH_APPLICATION_HOST' REQUIRE X509;
```

Test from the application host using hostname verification:

```sh
DB_NAME="REPLACE_WITH_MARIADB_DNS_NAME"
mariadb --host="$DB_NAME" --ssl-verify-server-cert \
  --ssl-ca=/etc/xmrpool/tls/root_ca.crt \
  --ssl-cert=/etc/xmrpool/tls/mariadb-client.crt \
  --ssl-key=/etc/xmrpool/tls/mariadb-client.key
```

## 5. Administrator MariaDB client certificate

Use the administrator's accountable identity:

```sh
sudo scripts/issue-x509.sh \
  --environment dev \
  --kind admin-client \
  --subject "$ADMIN_NAME" \
  --output-dir /root/bmca-issued/admin-client \
  --provisioner-password-file /root/.bmca \
  --key-password-file /root/.bmca-leaf
```

Create or alter the corresponding MariaDB account with `REQUIRE X509`, deploy
the files only to the administrator's secured workstation, and test using the
same `mariadb` TLS options above.

## 6. Completion

Record certificate serial numbers and expirations:

```sh
CERTIFICATE="REPLACE_WITH_CERTIFICATE_PATH"
test -f "$CERTIFICATE"
openssl x509 -in "$CERTIFICATE" -noout -serial -enddate -fingerprint -sha256
```

Remove staging copies only after the deployed service and client connections
have passed verification. Never commit issued private keys or leaf-password
files. Renewal currently means issuing and deploying a replacement before the
old certificate expires; revocation is not implemented in this release.
