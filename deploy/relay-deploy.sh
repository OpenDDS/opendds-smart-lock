#!/bin/bash
#
#   Deploy OpenDDS relay to Debian server. This script must be run
#   with elevated permissions.
#

if [ $# -ne 2 ]; then
    echo "ERROR: Expect an rtps.ini file and a directory containing security docs to be passed!"
    exit 1
fi

MOUNT_DIR=/opt/workspace
mkdir -p ${MOUNT_DIR}
cp $1 ${MOUNT_DIR}
mkdir -p ${MOUNT_DIR}/certs
cp $2/* ${MOUNT_DIR}/certs

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
make_relay_service

systemctl start rtps-relay
