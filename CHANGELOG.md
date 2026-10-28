# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases are listed in reverse publication order. Only categories with changes
are shown; fixes are listed under Changed. Releases containing only version
metadata or whitespace changes are omitted.

---

## [Unreleased]

## [Release 1.0.1] - 2026-10-28 05:16 EDT

## [Release 1.0.0] - 2026-10-04 05:41 EDT

### Added

- GitHub and personal website links in the documentation site's author sidebar.

---

## [Release 0.8.8] - 2026-09-27 07:46 EDT

### Added

- Documentation-site visit counting through the configured Count endpoint.

---

## [Release 0.8.7] - 2026-08-28 04:44 EDT

### Added

- A MariaDB certificate verification example showing how to inspect connection status and confirm TLS use.

---

## [Release 0.8.6] - 2026-08-27 18:30 EDT

### Summary

Corrects MariaDB certificate deployment and configures local command-line clients to trust the installed CA.

### Changed

- Stop appending the intermediate certificate to the issued server certificate during deployment.
- Back up the existing MariaDB client configuration alongside certificates and keys before replacing it.

### Added

- A configurable MariaDB client configuration file, installed as `60-bmca-client.cnf`, that sets the trusted CA certificate.

---

## [Release 0.8.5] - 2026-08-27 18:19 EDT

### Summary

Changes CA installation to a clean rebuild. After confirmation, installation deletes existing BMCA and Smallstep configuration and state, including CA identity, keys, provisioners, and database contents. Operators must initialize the CA again and regenerate and redeploy project certificates.

### Changed

- Rename `scripts/install.sh` to `scripts/install-ca.sh`.
- Validate installation paths before removing existing files, stop and disable the existing service, and leave the newly installed service disabled until initialization.
- Update setup instructions and static checks for the clean installation workflow.

### Removed

- Reinstallation behavior that preserved existing CA state and automatically restarted the existing CA.

---

## [Release 0.9.0] - 2026-08-27 18:04 EDT

### Summary

Introduces a separate installation workflow for certificate target hosts, including application, web, and database servers. Targets receive the certificate deployment tools and their own public settings.

### Changed

- Load MariaDB certificate deployment settings from `conf/target-settings.cfg`.
- Make the leaf-key password path, MariaDB service, group, certificate destinations, and backup directory configurable.
- Move certificate distribution settings out of the CA host configuration and update target-host documentation and static checks.

### Added

- `scripts/install-ca-target.sh` to install certificate-target tools under `/opt/bmca`.
- `conf/target-settings.cfg` and an installation guide for target hosts.

---

## [Release 0.8.4] - 2026-08-27 04:55 EDT

### Changed

- Fix EXIT-trap cleanup in `install-db-cert.sh` and `new-xmr-certs.sh` so temporary workspaces remain accessible to cleanup handlers after their main functions return.
- Clarify that MariaDB certificate installation requires the BMCA deployment tools and standard utilities on the target host.

---

## [Release 0.8.3] - 2026-08-27 04:47 EDT

### Summary

Extends newly issued X.509 certificates to a default lifetime of one year.

### Changed

- Increase `X509_DEFAULT_LIFETIME` from `24h` to `8760h`.
- Increase `X509_MAX_LIFETIME` from `168h` to `8760h`.

---

## [Release 0.8.2] - 2026-08-27 04:35 EDT

### Changed

- Correct homepage links to the renamed MariaDB certificate installation guides.

---

## [Release 0.8.1] - 2026-08-27 04:31 EDT

### Summary

Documents the automated MariaDB certificate deployment workflow and preserves the manual procedure as a separate guide.

### Changed

- Rename the existing MariaDB installation guide to distinguish the manual procedure from automated installation.

### Added

- A MariaDB certificate installer guide covering prerequisites, invocation, validation, deployed files, backups, and temporary-file cleanup.

---

## [Release 0.8.0] - 2026-08-26 18:05 EDT

### Summary

Automates MariaDB server certificate deployment from XMR environment archives, including verification, key decryption, backup of existing files, and service restart.

### Added

- `scripts/install-db-cert.sh` with environment and database-subject validation.
- Archive retrieval and SHA-256 verification, selective extraction, certificate-chain and hostname verification, and certificate/private-key matching.
- Installation of MariaDB certificate and key files with controlled ownership and permissions.
- Configurable certificate source host and archive directory, with static validation.

---

## [Release 0.7.1] - 2026-08-26 04:32 EDT

### Changed

- Align the NFS mount and development/production backup target paths with the automounter location at `/imports/bmca`.

---

## [Release 0.7.0] - 2026-08-26 04:24 EDT

### Summary

Replaces the incomplete MariaDB certificate installation instructions with a full manual deployment procedure.

### Changed

- Document transfer and checksum verification of XMR environment archives.
- Extract only the CA certificates and selected database certificate/key pair.
- Document server-chain assembly, runtime-key decryption, file ownership and permissions, MariaDB TLS settings, restart, and verification.

---

## [Release 0.6.6] - 2026-08-26 03:48 EDT

### Summary

Changes XMR certificate generation to publish archives and checksums only, removing loose certificate and key files after packaging.

### Changed

- Generate XMR certificates in a temporary workspace and publish only environment archives and checksum files under `./certs`.
- Create the output directory with mode `0700` and refuse to overwrite it.

### Removed

- Retained loose certificate and key files after archive creation; temporary workspaces are cleaned up automatically.

---

## [Release 0.6.5] - 2026-08-26 03:37 EDT

### Summary

Packages XMR Pool certificates for deployment by environment, with CA chains and integrity checks included in each distribution.

### Changed

- Group certificate issuance by development, QA, and production environment.
- Update XMR output documentation and reorganize the MariaDB installation guide.

### Added

- Development, QA, and production `tar.gz` archives containing the appropriate certificates, encrypted keys, and CA chain.
- SHA-256 checksum files for each archive, restrictive file permissions, and overwrite checks.

---

## [Release 0.6.4] - 2026-08-25 05:04 EDT

### Changed

- Update XMR certificate documentation and DNS examples for application servers.

### Added

- Five application-server certificates in `new-xmr-certs.sh`, increasing the generated set from 17 to 22 certificate/key pairs.
- Example CA setup command output.

---

## [Release 0.6.3] - 2026-08-25 03:58 EDT

### Summary

Changes the environment selector used by every management command. Existing command invocations must replace `--environment` with `--env`.

### Changed

- Rename the CLI option `--environment` to `--env` throughout the scripts, documentation, and tests.

---

## [Release 0.6.2] - 2026-08-24 03:09 EDT

### Removed

- The redundant page heading from the XMR certificate generation guide.

---

## [Release 0.6.1] - 2026-08-24 02:54 EDT

### Added

- Example output from the XMR Pool project's `dns-report.sh` tool to document the DNS names used for certificate generation.

---

## [Release 0.6.0] - 2026-08-24 02:51 EDT

### Changed

- Reorganize homepage navigation into CA host and target host operations.
- Move XMR certificate generation instructions from the homepage into a dedicated operations guide.

---

## [Release 0.5.3] - 2026-08-23 17:58 EDT

### Added

- Missing XMR generation instructions describing default password files and the requirement for a new output directory.

---

## [Release 0.5.2] - 2026-08-23 17:56 EDT

### Summary

Introduces batch certificate generation for the XMR Pool project across development, QA, and production services.

### Added

- `scripts/new-xmr-certs.sh` to issue 17 web, admin, cluster, and MariaDB server certificate/key pairs through the production CA.
- Options for output location, provisioner and key password files, and certificate lifetime.
- Homepage usage instructions for generating XMR certificates.

---

## [Release 0.5.1] - 2026-08-23 15:29 EDT

### Removed

- XMR deployment topology and DNS tables from the homepage.

---

## [Release 0.5.0] - 2026-08-23 15:26 EDT

### Added

- Deployment topology and DNS tables for development, QA, and production XMR Pool environments.

---

## [Release 0.4.5] - 2026-08-23 14:25 EDT

### Summary

Restricts certificate issuance to root on the CA host assigned to the selected environment.

### Changed

- Require root privileges and execution on the matching CA host when issuing X.509 or SSH certificates.
- Expand certificate issuance instructions and static checks for those requirements.

---

## [Release 0.4.4] - 2026-08-23 13:46 EDT

### Changed

- Polish installation, setup, and certificate issuance examples and their formatting.

---

## [Release 0.4.3] - 2026-08-23 13:37 EDT

### Changed

- Improve CA setup command examples and homepage formatting.

### Removed

- Shell prompts from CA setup examples so commands can be copied directly.

---

## [Release 0.4.2] - 2026-08-23 05:00 EDT

### Removed

- Shell prompts from installation command examples so commands can be copied directly.

---

## [Release 0.4.0] - 2026-08-22 06:44 EDT

### Summary

Replaces the offline initialization and transfer workflow with initialization on the CA host. Root CA material is retained in a root-only BMCA directory and included in encrypted backups.

### Changed

- Include the local root CA in backup and restore operations while keeping it separate from Smallstep runtime state.
- Sign intermediate rotation requests with the local root CA.
- Update setup, backup, restore, rotation, and uninstall instructions for local root custody.
- Document that uninstalling BMCA removes its local root CA directory while preserving Smallstep runtime state.

### Added

- `scripts/initialize-bmca.sh` to create, install, start, and validate the CA on its host.
- `BMCA_ROOT_CA_DIR` for root CA material under `/var/lib/bmca/root-ca`.
- Tests covering local initialization and root CA inclusion in encrypted backups.

### Removed

- `scripts/initialize-ca.sh` and its offline, import, and local subcommands.
- The separate offline initialization test and the `--offline-workspace` option for intermediate signing.

---

## [Release 0.3.1] - 2026-08-22 06:14 EDT

### Summary

Adds a local initialization option that performs CA creation and import on the CA host, and improves service startup after restoration.

### Changed

- Enable and start `step-ca.service` after restoring a CA.
- Expand setup, SSH issuance, intermediate rotation, restoration, and uninstall documentation.

### Added

- The `initialize-ca.sh local` command, retaining root material in a root-only workspace.
- A local initialization integration test.

---

## [Release 0.3.0] - 2026-08-22 05:33 EDT

### Summary

Corrects service startup during installation so a complete existing CA starts automatically and an uninitialized CA stays disabled.

### Changed

- Start and enable an existing CA during installation only when both its configuration and password file are present; otherwise leave the service disabled.
- Guard `step-ca.service` startup with configuration and password-file existence checks.
- Make provisioner-configuration rollback tolerate an already-removed rollback file.

---

## [Release 0.2.42] - 2026-08-22 04:58 EDT

### Changed

- Correct installation-page links to the CA setup procedure.

### Removed

- Redundant documentation and operations index pages.

---

## [Release 0.2.41] - 2026-08-22 04:44 EDT

### Changed

- Correct homepage operation links after moving the guides to `pages/ops`.

---

## [Release 0.2.40] - 2026-08-22 03:26 EDT

### Changed

- Move operational guides from `pages/use-cases` to `pages/ops`.
- Turn the homepage into the operations entry point with CA host and target host navigation.

---

## [Release 0.2.39] - 2026-08-21 03:56 EDT

### Summary

Reorganizes the documentation around focused operational procedures for CA hosts and certificate target hosts.

### Changed

- Replace the documentation roadmap with task-oriented operations navigation.
- Rewrite installation instructions around the supported host workflow.

### Added

- Dedicated setup, backup, restore, certificate issuance, uninstall, MariaDB, Python database client, and Caddy guides.

### Removed

- Superseded design documents, runbooks, and older database issuance and uninstall guides.

---

## [Release 0.2.38] - 2026-08-21 03:29 EDT

### Summary

Integrates certificate-type-specific Smallstep provisioners and templates, and improves installation and uninstallation around existing CA state.

### Changed

- Select the matching provisioner when issuing each X.509 certificate type and require SANs for server and replication certificates.
- Install certificate templates alongside the scripts.
- Stop and restart an active CA when replacing installed BMCA files, with recovery if installation fails.
- Remove BMCA configuration and local work state on uninstall while preserving Smallstep programs and CA runtime state.

### Added

- `scripts/initialize-step-ca.sh` to configure web, database server, replication, application client, and administrator provisioners.
- Five X.509 certificate templates, a MariaDB replication certificate kind, and configurable lifetime bounds.
- Uninstall documentation and expanded static and initialization checks.

---

## [Release 0.2.37] - 2026-08-15 10:13 EDT

### Changed

- Correct Jekyll front matter to use lowercase keys and the `single` layout in the use-case index, installation guide, and database certificate guide.

---

## [Release 0.2.36] - 2026-08-15 10:09 EDT

### Changed

- Correct the Jekyll include directory from `_pages` to `pages`.

---

## [Release 0.2.35] - 2026-08-15 10:05 EDT

### Added

- Author profiles on the documentation index and use-case pages.

---

## [Release 0.2.34] - 2026-08-15 10:00 EDT

### Changed

- Correct the logo path in the installation guide.

### Added

- The BMCA logo in the MariaDB certificate guide.

---

## [Release 0.2.33] - 2026-08-15 09:58 EDT

### Changed

- Update use-case navigation to extensionless installation and database certificate URLs.

---

## [Release 0.2.32] - 2026-08-15 06:26 EDT

### Changed

- Correct the site logo path to `/pages/images/bmca-logo.png`.
- Adjust front-matter casing in the installation and database certificate guides.

---

## [Release 0.2.31] - 2026-08-15 06:22 EDT

### Changed

- Adjust title and layout front-matter casing in the use-case index.

---

## [Release 0.2.30] - 2026-08-15 06:18 EDT

### Changed

- Correct the site URL and homepage logo path.
- Update front matter and headings on the use-case index and database certificate guide.

### Added

- Jekyll front matter in the installation guide.

---

## [Release 0.2.29] - 2026-08-15 06:06 EDT

### Changed

- Expand MariaDB SSL documentation with certificate deployment, configuration, and connection examples.

---

## [Release 0.2.28] - 2026-08-15 05:57 EDT

### Summary

Expands deployment instructions and introduces a dedicated MariaDB certificate issuance guide.

### Changed

- Change the default installation source directory from `/opt/dev/bmca` to `/root/bmca`.
- Expand installation instructions.
- Enhance `scripts/new-release.sh` usage output with examples based on the current project version.

### Added

- A database certificate guide covering MariaDB certificate issuance and deployment.

---

## [Release 0.2.27] - 2026-08-13 05:35 EDT

### Changed

- Make the site logo background transparent.

---

## [Release 0.2.25] - 2026-08-13 04:45 EDT

### Changed

- Switch the documentation website from the plum skin to the dark skin.

---

## [Release 0.2.24] - 2026-08-13 04:21 EDT

### Changed

- Show usage and exit with an error when the installer is invoked without arguments.

---

## [Release 0.2.23] - 2026-08-13 04:17 EDT

### Changed

- Switch the documentation website skin from neon to plum.
- Exclude the development online transfer archive from Git tracking.

---

## [Release 0.2.20] - 2026-08-12 05:25 EDT

### Changed

- Use the project's Minimal Mistakes theme fork for the documentation website.

---

## [Release 0.2.14] - 2026-08-12 04:41 EDT

### Changed

- Rework the homepage around supported use cases.

### Added

- A use-case index, an installation page placeholder, and front matter for documentation pages.

---

## [Release 0.2.12] - 2026-08-11 16:49 EDT

### Changed

- Correct the logo filename and update site URL and author settings.

---

## [Release 0.2.11] - 2026-08-11 16:43 EDT

### Changed

- Update site administrator details and the copyright start year.

### Removed

- The previous author's social links.

---

## [Release 0.2.10] - 2026-08-11 06:01 EDT

### Changed

- Update the configured logo path to the images directory.

---

## [Release 0.2.9] - 2026-08-11 05:56 EDT

### Changed

- Restore Jekyll site and Minimal Mistakes theme settings in `_config.yml` after it had been replaced with workflow configuration.

---

## [Release 0.2.8] - 2026-08-11 05:52 EDT

### Summary

Replaces the empty-commit rebuild workflow with a Jekyll build and GitHub Pages deployment pipeline.

### Changed

- Build and upload the site as a Pages artifact, then deploy it in a separate job.
- Trigger deployment on pushes to `main` and through manual dispatch.
- Rework website configuration during theme development.

### Added

- Pages deployment permissions, environment configuration, and deployment concurrency controls.

---

## [Release 0.2.7] - 2026-08-11 05:37 EDT

### Added

- A manually triggered GitHub Actions workflow to request documentation-site rebuilds.

---

## [Release 0.2.6] - 2026-08-11 05:24 EDT

### Changed

- Simplify Jekyll configuration and switch to the Minimax remote theme.
- Update homepage layout and logo references.

---

## [Release 0.2.3] - 2026-08-10 05:41 EDT

### Changed

- Move documentation from `docs` to `pages` for website publication.
- Expand the homepage introduction and link it to the documentation index.

---

## [Release 0.2.1] - 2026-08-10 05:22 EDT

### Changed

- Update site identity settings and correct the configured logo reference.

---

## [Release 0.2.0] - 2026-08-10 05:18 EDT

### Summary

Introduces the public documentation website and links it to the existing operational documentation.

### Changed

- Rename the documentation README to an index page for website navigation.

### Added

- Jekyll configuration, a homepage, and the BMCA site logo.
- Custom domain configuration for `bmca.osoyalce.com`.

---

## [Release 0.1.3] - 2026-08-09 20:16 EDT

### Changed

- Expand installation documentation with separate development and production procedures, identity and release checks, backup prerequisites, and installation verification.

---

## [Release 0.1.2] - 2026-08-09 20:10 EDT

### Summary

Repairs incomplete deployments caused by Git ignoring the shared shell library required by the management scripts.

### Changed

- Exempt `scripts/lib` and its shell files from Git ignore rules.
- Check for the shared library in installation instructions and static validation.

### Added

- The previously missing `scripts/lib/common.sh`, including settings loading, environment selection, host checks, confirmation, and secret-file permission checks.

---

## [Release 0.1.1] - 2026-08-09 20:02 EDT

### Added

- A documentation roadmap linking the design, deployment, operational lifecycle, recovery, and testing guides.

---

## [Release 0.1.0] - 2026-08-09 19:51 EDT

### Summary

Introduces the initial CA management implementation, with separate development and production environments and an offline-root/online-intermediate workflow.

### Changed

- Record the project version in `conf/settings.cfg` and update the release script to manage settings and changelog entries.

### Added

- CA installation, offline initialization and online import, X.509 and SSH certificate issuance, validation, intermediate rotation, encrypted backup, restoration, and uninstall scripts.
- Public configuration and a Smallstep systemd service.
- Architecture and issuance policy documentation with operational runbooks.
- Static, CLI, initialization, and backup tests.

### Removed

- The standalone `VERSION` file.

---

## [Release 0.0.1] - 2026-08-09 18:31 EDT

### Summary

Bootstraps the repository and automated Git release workflow before the CA management implementation.

### Added

- The initial project skeleton, license, Git ignore rules, and README.
- Installation and uninstall script placeholders.
- A release script for the feature, development, and main branch workflow.
