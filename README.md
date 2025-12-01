# idp-shibboleth-vm

Lightweight installer and configuration bundle to deploy a Shibboleth Identity Provider (IdP) on Tomcat 10 (Debian/Ubuntu). The repository contains a prepared Tomcat systemd unit, Tomcat configuration, Shibboleth IdP config snippets and an installer script that performs the installation and basic configuration.

IMPORTANT: Fill required variables in install.sh before running
- This installer expects you to pre-fill configuration variables at the top of install.sh. The script does not prompt for these values at runtime. Edit install.sh and set:
  - HOSTNAME — server hostname (e.g. idp.example.org)
  - LDAPHOST — LDAP server (e.g. ldap.example.org)
  - LDAPDN — LDAP domain (e.g. example.org)
  - LDAPBASE — LDAP base DN (e.g. OU=Account,DC=example,DC=org)
  - LDAPUSER — LDAP bind user (e.g. user@example.org)
  - LDAPPASS — LDAP bind password
  - Optional installer variables you may want to adjust:
    - IDP_VERSION (default 5.1.6)
    - KP_PASSWORD and SP_PASSWORD (keypair/service passwords used during IdP install)
    - IDP_INSTALL_DIR (default /opt/shibboleth-idp)
    - TOMCAT_SERVICE (default tomcat10)

See the "Important variables in the installer" section below for locations.

## Summary

- Installer: install.sh — checks for root, required files, installs packages, downloads the IdP, and deploys configuration.
- IdP target directory: configured by IDP_INSTALL_DIR in install.sh (default `/opt/shibboleth-idp`).
- IdP version: configured by IDP_VERSION in install.sh (default `5.1.6`).
- Tomcat service override, Tomcat configs and IdP fragments are provided in the repo.

## Quick start / Usage

1. Edit install.sh and set the required variables (see IMPORTANT above).
2. Place the required files in the repository root:
   - foo.p12, tomcat10.service, catalina.properties, server.xml, idp.xml, services.xml, attribute-resolver.xml, ldap.properties.template, relying-party.xml
3. Make the installer executable and run as root:
```sh
sudo bash ./install.sh
```
4. After successful run:
   - Shibboleth IdP is installed at `${IDP_INSTALL_DIR}`.
   - Access the IdP at: https://${HOSTNAME}/idp/shibboleth

## Configuration notes

- ldap.properties.template is processed with envsubst by the installer; ensure LDAP variables are set in install.sh.
- The PKCS#12 keystore file must be present as foo.p12 and will be moved into Tomcat credentials by the script.
- The installer clones java-idp-tomcat-base and copies libraries into Tomcat lib.

## Files in this repository

- install.sh — installer script (edit variables at top before running).
- ldap.properties.template, catalina.properties, server.xml, tomcat10.service, idp.xml, services.xml, attribute-resolver.xml, relying-party.xml — configuration fragments used by the installer.

## Important variables in the installer (edit before run)

- HOSTNAME, LDAPHOST, LDAPDN, LDAPBASE, LDAPUSER, LDAPPASS — required and must be set.
- IDP_VERSION, KP_PASSWORD, SP_PASSWORD, IDP_INSTALL_DIR, TOMCAT_SERVICE — optional defaults in install.sh; change if needed.

## Troubleshooting

- Script must be run as root (checks $EUID).
- Uses apt to install packages (openjdk-17-jre, tomcat10, git, wget).
- If systemd does not pick up the custom unit file, run:
```sh
systemctl daemon-reload
systemctl restart tomcat10
```

## License

Configuration and scripts for local deployment. Verify upstream licenses for Tomcat, Shibboleth IdP and Java.

## Further customization

Edit Tomcat and IdP config fragments in the repository before running the installer to adapt SSL, connectors, LDAP filters and attribute mappings.