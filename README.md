# idp-shibboleth-vm

Lightweight installer and configuration bundle to deploy a Shibboleth Identity Provider (IdP) on Tomcat 10 (Debian/Ubuntu). The repository contains a prepared Tomcat systemd unit, Tomcat configuration, Shibboleth IdP config snippets and an installer script that performs the installation and basic configuration.

## Summary

- Installer: [install.sh](install.sh) — prompts for host and LDAP values, installs packages, downloads the IdP, and deploys configuration.
- IdP target directory: [`IDP_INSTALL_DIR` in install.sh](`install.sh`) — default `/opt/shibboleth-idp`.
- IdP version downloaded: [`IDP_VERSION` in install.sh](`install.sh`) — default `5.1.6`.
- Tomcat service overridden by: [tomcat10.service](tomcat10.service).
- Tomcat configuration: [catalina.properties](catalina.properties) and [server.xml](server.xml).
- LDAP template: [ldap.properties.template](ldap.properties.template) — processed with envsubst by the installer.
- Required local files: [`REQUIRED_FILES` in install.sh](`install.sh`) — ensure these exist before running.

## Quick start / Usage

1. Place the required files in the repository root:
   - foo.p12, tomcat10.service, catalina.properties, server.xml, idp.xml, services.xml, attribute-resolver.xml, ldap.properties.template, relying-party.xml
   See [`REQUIRED_FILES`](install.sh) in [install.sh](install.sh).

2. Make the installer executable and run as root:
```sh
sudo bash ./install.sh
```

3. Follow the interactive prompts:
   - Enter server HOSTNAME (e.g. idp.example.org)
   - Enter LDAP host, domain, baseDN, user and password

4. After successful run:
   - Shibboleth IdP is installed at the path set in [`IDP_INSTALL_DIR`](install.sh) (default: `/opt/shibboleth-idp`).
   - Access the IdP at: https://<HOSTNAME>/idp/shibboleth
   - Tomcat service name used by the script: [`TOMCAT_SERVICE`](install.sh) (default: `tomcat10`)

## Configuration

- LDAP configuration is generated from [ldap.properties.template](ldap.properties.template) by the installer (uses envsubst).
- Credentials keystore: move your PKCS#12 file to `foo.p12` in the repo root before running — installer will place it in Tomcat credentials.
- You can edit the following files to customize Tomcat and IdP behavior before installing:
  - [catalina.properties](catalina.properties)
  - [server.xml](server.xml)
  - [idp.xml](idp.xml)
  - [services.xml](services.xml)
  - [attribute-resolver.xml](attribute-resolver.xml)
  - [relying-party.xml](relying-party.xml)
  - [tomcat10.service](tomcat10.service)

## Files in this repository

- [install.sh](install.sh) — installer script (checks for root, required files, prompts for values, installs packages, downloads and installs IdP).
- [ldap.properties.template](ldap.properties.template) — template used to generate `${IDP_INSTALL_DIR}/conf/ldap.properties`.
- [catalina.properties](catalina.properties) — Tomcat configuration used by the installer.
- [server.xml](server.xml) — Tomcat connectors and SSL config.
- [tomcat10.service](tomcat10.service) — systemd unit file deployed to override default Tomcat.
- [idp.xml](idp.xml) — Tomcat context for the IdP webapp.
- [services.xml](services.xml) — Shibboleth services configuration.
- [attribute-resolver.xml](attribute-resolver.xml) — attribute resolver definitions.
- [relying-party.xml](relying-party.xml) — relying party defaults.
- [README.md](README.md) — this file.

## Important variables in the installer

- [`IDP_VERSION`](install.sh) — version to download.
- [`IDP_INSTALL_DIR`](install.sh) — installation target (default `/opt/shibboleth-idp`).
- [`KP_PASSWORD`](install.sh) and [`SP_PASSWORD`](install.sh) — keypair and service provider passwords used during IdP install.
- [`REQUIRED_FILES`](install.sh) — list of files the installer requires.
- [`TOMCAT_SERVICE`](install.sh) — tomcat service name used to stop/start.

## Notes & troubleshooting

- The installer must be run as root (it checks `$EUID`).
- The installer installs packages via apt (OpenJDK 17, tomcat10, git, wget).
- The script clones `java-idp-tomcat-base` and copies Tomcat libs into `/var/lib/tomcat10/lib/`.
- If systemd does not pick up the custom unit file, run:
```sh
systemctl daemon-reload
systemctl restart tomcat10
```
- If you need to change the IdP version or install directory, edit the variables in [install.sh](install.sh) before running.

## License

Project content is configuration and scripts for local deployment. Check licences of upstream components (Tomcat, Shibboleth IdP, Java).

## Contact / Further customization

Edit the files listed above to adapt SSL, Tomcat connectors, LDAP search filters and attribute mappings before running the installer. For advanced customization refer to Shibboleth IdP documentation.