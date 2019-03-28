#!/bin/bash

sudo apt-get update -y

install_docker() {
    # See https://docs.docker.com/install/linux/docker-ce/debian/

    # Allow apt to use repositories over HTTPS
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg2 \
        software-properties-common

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

    # Add the stable docker repo
    sudo add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/debian \
            $(lsb_release -cs) \
            stable"
    
    # Refresh repo and install docker community edition
    sudo apt-get update -y && sudo apt-get install -y docker-ce

    # Add user to docker group
    sudo usermod -aG docker $USER
}

make_relay_image() {
docker build -t opendds/relay - <<'DOCKERFILE'
from objectcomputing/opendds:master
RUN cd /opt/OpenDDS/tools/rtpsrelay && mwc.pl -type gnuace && make
ENV PATH="$PATH:/opt/OpenDDS/tools/rtpsrelay"
DOCKERFILE
}

relay_run() {
    docker run --rm -d -p 4444-4446:4444-4446/udp --name relay opendds/relay \
        RtpsRelay -DCPSConfigFile /opt/OpenDDS/tools/rtpsrelay/rtps.ini
}

relay_logs() {
    docker logs relay
}

case "${1}" in
    install-docker)
        install_docker
        ;;
    make-relay-image)
        make_relay_image
        ;;
    run)
        relay_run
        ;;
    logs)
        relay_logs
        ;;
    -h|--help)
        echo "Usage: relay-deploy.sh install-docker | make-relay-image | run-relay"
        ;;
esac
