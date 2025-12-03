#!/usr/bin/env bash
# Simple Shibboleth IdP + Tomcat10 installer
# Usage: sudo ./install.sh

# ======== Configuration - Fill in the variables below before running the script ========
export HOSTNAME="" # Enter server HOSTNAME (e.g. idp.example.org)
export LDAPHOST="" # Enter server LDAP (e.g. ldap.example.org)
export LDAPDN="" # Enter domain LDAP (e.g. example.org)
export LDAPBASE="" # Enter baseDN LDAP (e.g. OU=Account,DC=example,DC=org)
export LDAPUSER="" # Enter user LDAP (e.g. user@example.org)
export LDAPPASS="" # Enter password LDAP

# ====== Configuration Variables ======
export IDP_VERSION="5.1.6"
export KP_PASSWORD="inikppassword"
export SP_PASSWORD="inisppassword"
export IDP_INSTALL_DIR="/opt/shibboleth-idp"
export TOMCAT_SERVICE="tomcat10"

set -euo pipefail

# ====== Check for root ======
if [[ $EUID -ne 0 ]]; then
  echo "❌ This script must be run as root." >&2
  exit 1
fi

# ====== Required Local Files ======
REQUIRED_FILES=(
  "attribute-filter.xml"
  "attribute-resolver.xml"
  "catalina.properties"
  "idp.xml"
  "ldap.properties"
  "metadata-providers.xml"
  "relying-party.xml"
  "server.xml"
  "services.xml"
  "shibboleth-identity-provider-${IDP_VERSION}.tar.gz"
  "tomcat10.service"
)

# ====== Check required files ======
echo "==> Performing sanity checks..."
for f in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "❌ Missing required file: $f"
    echo "Make sure it exists in the current directory: $(pwd)"
    exit 1
  fi
done
echo "✅ All required files are present."

# ====== Begin Installation ======
echo "==> Change repository"
sed -i 's|cdn.repo.cloudeka.id/ubuntu/|mirror.amscloud.co.id/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources

echo "==> Installing dependencies (OpenJDK 17 & Tomcat 10)..."
apt update
apt install -y openjdk-17-jre tomcat10 git wget

echo "==> Stopping Tomcat..."
systemctl stop "${TOMCAT_SERVICE}".service || true

echo "==> Copying IdP Tomcat base libraries..."
cp ./tomcat-base/lib/* /var/lib/tomcat10/lib/

echo "==> Generating p12 cert for Tomcat"
openssl req -x509 -newkey rsa:4096 \
    -keyout key.pem -out cert.pem \
    -days 365 -nodes \
    -subj "/C=ID/ST=State/L=City/O=Organization/OU=Unit/CN=${HOSTNAME}/emailAddress=idp@${HOSTNAME}"
openssl pkcs12 -export \
    -in cert.pem -inkey key.pem \
    -out tomcat.p12 -name tomcat \
    -passout pass:"12345"

echo "==> Setting up Tomcat credentials directory..."
mkdir -p /var/lib/tomcat10/credentials
mv tomcat.p12 /var/lib/tomcat10/credentials/idp-userfacing.p12
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
cat attribute-filter.xml > "${IDP_INSTALL_DIR}/conf/attribute-filter.xml"
cat attribute-resolver.xml > "${IDP_INSTALL_DIR}/conf/attribute-resolver.xml"
cat metadata-providers.xml > "${IDP_INSTALL_DIR}/conf/metadata-providers.xml"
cat ldap.properties > "${IDP_INSTALL_DIR}/conf/ldap.properties"
sed -i "s/LDAPHOST/${LDAPHOST}/g" "${IDP_INSTALL_DIR}/conf/ldap.properties"
sed -i "s/LDAPBASE/${LDAPBASE}/g" "${IDP_INSTALL_DIR}/conf/ldap.properties"
sed -i "s/LDAPUSER/${LDAPUSER}/g" "${IDP_INSTALL_DIR}/conf/ldap.properties"
sed -i "s/LDAPDN/${LDAPDN}/g" "${IDP_INSTALL_DIR}/conf/ldap.properties"
sed -i "s/myServicePassword/${LDAPPASS}/g" "${IDP_INSTALL_DIR}/credentials/secrets.properties"
METADATA="${IDP_INSTALL_DIR}/metadata/idp-metadata.xml"
TMP_METADATA="${METADATA}.tmp"
awk -v ip="${HOSTNAME}" '
/<md:SingleLogoutService[[:space:]]+Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP"[[:space:]]+Location="https:\/\/[^"]*\/idp\/profile\/SAML2\/SOAP\/ArtifactResolution"[[:space:]]*\/>/ {
  print "<md:SingleLogoutService Binding=\"urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect\" Location=\"https://" ip "/idp/profile/SAML2/Redirect/SLO\" />";
  print "<md:SingleLogoutService Binding=\"urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST\" Location=\"https://" ip "/idp/profile/SAML2/POST/SLO\" />";
  print "<md:SingleLogoutService Binding=\"urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST-SimpleSign\" Location=\"https://" ip "/idp/profile/SAML2/POST-SimpleSign/SLO\" />";
}
{ print }
' "${METADATA}" > "${TMP_METADATA}" && mv "${TMP_METADATA}" "${METADATA}"

echo "==> Enabling Consent module..."
/opt/shibboleth-idp/bin/module.sh -t idp.intercept.Consent || \
/opt/shibboleth-idp/bin/module.sh -e idp.intercept.Consent

cat relying-party.xml > "${IDP_INSTALL_DIR}/conf/relying-party.xml"

echo "==> Reloading systemd..."
systemctl daemon-reload

echo "==> Starting Tomcat..."
systemctl start "${TOMCAT_SERVICE}.service"

echo "==> ✅ Installation complete!"
echo "Shibboleth IdP is installed at ${IDP_INSTALL_DIR}"
echo "Access it at: https://${HOSTNAME}/idp/shibboleth"