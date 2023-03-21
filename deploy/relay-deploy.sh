#!/bin/bash
#
#   Deploy OpenDDS relay to Debian server. This script must be run
#   with elevated permissions.
#

if [ $# -ne 3 ]; then
    echo "ERROR: Expect username/password to the permission manager and an rtps.ini file to be passed."
    echo "Usage: $0 username password path_to_ini_file"
    exit 1
fi

MOUNT_DIR=/opt/workspace
mkdir -p ${MOUNT_DIR}
cp $3 ${MOUNT_DIR}

DPM_USERNAME=$1
DPM_PASSWORD=$2

apt-get update -y

install_docker() {
    # See https://docs.docker.com/install/linux/docker-ce/debian/

    # Allow apt to use repositories over HTTPS
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg2 \
        software-properties-common

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -

    # Add the stable docker repo
    add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/debian \
            $(lsb_release -cs) \
            stable"

    # Refresh repo and install docker community edition
    apt-get update -y && apt-get install -y docker-ce

    # Add user to docker group
    usermod -aG docker $USER
}

download_security_docs() {
    NONCE=relaynonce
    API_URL=https://dpm.unityfoundation.io/api
    CERTS_DIR=${MOUNT_DIR}/certs

    mkdir -p ${CERTS_DIR}
    curl -c cookies.txt -H'Content-Type: application/json' -d"{\"username\":\"${DPM_USERNAME}\",\"password\":\"$DPM_PASSWORD\"}" ${API_URL}/login
    curl --silent -b cookies.txt "${API_URL}/applications/identity_ca.pem" > ${CERTS_DIR}/identity_ca.pem
    curl --silent -b cookies.txt "${API_URL}/applications/permissions_ca.pem" > ${CERTS_DIR}/permissions_ca.pem
    curl --silent -b cookies.txt "${API_URL}/applications/governance.xml.p7s" > ${CERTS_DIR}/governance.xml.p7s
    curl --silent -b cookies.txt "${API_URL}/applications/key_pair?nonce=${NONCE}" > key-pair
    curl --silent -b cookies.txt "${API_URL}/applications/permissions.xml.p7s?nonce=${NONCE}" > ${CERTS_DIR}/permissions.xml.p7s
    jq -r '.public' key-pair > ${CERTS_DIR}/identity.pem
    jq -r '.private' key-pair > ${CERTS_DIR}/identity_key.pem
    rm -f cookies.txt key-pair
}

make_relay_service() {
    cat > /etc/systemd/system/rtps-relay.service <<SERVICE
[Unit]
Description=Relay for RTPS
After=network.target
[Service]
ExecStart=/usr/bin/docker run --log-driver none --rm -p 4444-4446:4444-4446/udp --name relay --mount type=bind,source=/opt/workspace,target=/opt/workspace ghcr.io/opendds/opendds:latest-release /opt/OpenDDS/tools/rtpsrelay/RtpsRelay -Id id -VerticalAddress 0.0.0.0:4444 -IdentityCA /opt/workspace/certs/identity_ca.pem -PermissionsCA /opt/workspace/certs/permissions_ca.pem -IdentityCertificate /opt/workspace/certs/identity.pem -IdentityKey /opt/workspace/certs/identity_key.pem -Governance /opt/workspace/certs/governance.xml.p7s -Permissions /opt/workspace/certs/permissions.xml.p7s -DCPSConfigFile /opt/workspace/rtps.ini
ExecStop=/usr/bin/docker stop relay
[Install]
WantedBy=multi-user.target
SERVICE

    chmod 0644 /etc/systemd/system/rtps-relay.service
    systemctl daemon-reload
    systemctl enable rtps-relay
}

install_docker
download_security_docs
make_relay_service

systemctl start rtps-relay
