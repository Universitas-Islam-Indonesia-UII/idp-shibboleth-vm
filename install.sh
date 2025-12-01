#!/usr/bin/env bash
set -euo pipefail

# Simple Shibboleth IdP + Tomcat10 installer with sanity checks
# Usage: sudo ./install-shib-idp.sh your.hostname.example

# ====== Required Local Files ======
REQUIRED_FILES=(
  "foo.p12"
  "tomcat10.service"
  "catalina.properties"
  "server.xml"
  "idp.xml"
  "services.xml"
  "attribute-resolver.xml"
  "ldap.properties"
  "relying-party.xml"
)

# ====== Check for root ======
if [[ $EUID -ne 0 ]]; then
  echo "❌ This script must be run as root." >&2
  exit 1
fi

# ====== Check for hostname argument ======
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 HOSTNAME" >&2
  exit 1
fi

HOSTNAME="$1"

IDP_VERSION="5.1.6"
KP_PASSWORD="inikppassword"
SP_PASSWORD="inisppassword"
IDP_INSTALL_DIR="/opt/shibboleth-idp"
TOMCAT_SERVICE="tomcat10"

echo "==> Performing sanity checks..."

# ====== Check required files ======
for f in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "❌ Missing required file: $f"
    echo "Make sure it exists in the current directory: $(pwd)"
    exit 1
  fi
done

echo "✓ All required files are present."

# ====== Begin Installation ======

echo "==> Installing dependencies (OpenJDK 17 & Tomcat 10)..."
apt update
apt install -y openjdk-17-jre tomcat10 git wget

echo "==> Stopping Tomcat..."
service "${TOMCAT_SERVICE}" stop || true

echo "==> Cloning java-idp-tomcat-base (branch 10.1)..."
if [[ ! -d java-idp-tomcat-base ]]; then
  git clone https://git.shibboleth.net/git/java-idp-tomcat-base
fi
(
  cd java-idp-tomcat-base
  git fetch --all
  git checkout 10.1
)

echo "==> Copying IdP Tomcat base libraries..."
cp ./java-idp-tomcat-base/tomcat-base/lib/* /var/lib/tomcat10/lib/

echo "==> Setting up Tomcat credentials directory..."
mkdir -p /var/lib/tomcat10/credentials
mv foo.p12 /var/lib/tomcat10/credentials/idp-userfacing.p12
chown -R tomcat: /var/lib/tomcat10/credentials

echo "==> Installing custom tomcat10.service..."
cat tomcat10.service > /usr/lib/systemd/system/tomcat10.service

echo "==> Installing custom catalina.properties..."
cat catalina.properties > /var/lib/tomcat10/conf/catalina.properties

echo "==> Installing custom server.xml..."
cat server.xml > /var/lib/tomcat10/conf/server.xml

echo "==> Installing idp.xml context..."
mkdir -p /var/lib/tomcat10/conf/Catalina/localhost
cp idp.xml /var/lib/tomcat10/conf/Catalina/localhost/idp.xml

echo "==> Downloading Shibboleth IdP ${IDP_VERSION}..."
wget "https://shibboleth.net/downloads/identity-provider/${IDP_VERSION}/shibboleth-identity-provider-${IDP_VERSION}.tar.gz"

echo "==> Extracting Shibboleth IdP..."
tar -xzvf "shibboleth-identity-provider-${IDP_VERSION}.tar.gz"
rm -f "shibboleth-identity-provider-${IDP_VERSION}.tar.gz"

echo "==> Running Shibboleth IdP installer..."
"shibboleth-identity-provider-${IDP_VERSION}/bin/install.sh" \
  -t "${IDP_INSTALL_DIR}" \
  -h "${HOSTNAME}" \
  --scope idp.id \
  -e "https://${HOSTNAME}/idp/shibboleth" \
  -kp "${KP_PASSWORD}" \
  -sp "${SP_PASSWORD}"

chown -R tomcat: "${IDP_INSTALL_DIR}/"

echo "==> Installing IdP configuration files..."
cat services.xml > "${IDP_INSTALL_DIR}/conf/services.xml"
cat attribute-resolver.xml > "${IDP_INSTALL_DIR}/conf/attribute-resolver.xml"
cat ldap.properties > "${IDP_INSTALL_DIR}/conf/ldap.properties"

echo "==> Enabling Consent module..."
/opt/shibboleth-idp/bin/module.sh -t idp.intercept.Consent || \
/opt/shibboleth-idp/bin/module.sh -e idp.intercept.Consent

cat relying-party.xml > "${IDP_INSTALL_DIR}/conf/relying-party.xml"

echo "==> Reloading systemd..."
systemctl daemon-reload

echo "==> Starting Tomcat..."
service "${TOMCAT_SERVICE}" start

echo "==> ✅ Installation complete!"
echo "Shibboleth IdP is installed at ${IDP_INSTALL_DIR}"
echo "Access it at: https://${HOSTNAME}/idp/shibboleth"
