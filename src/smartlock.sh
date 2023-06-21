#!/bin/bash
#
# Usage: ./smartlock.sh lock1

BASE_PATH=/home/pi
LD_LIBRARY_PATH+="${LD_LIBRARY_PATH+:}${BASE_PATH}/pi-opendds/build/target/ACE_TAO/ACE/lib"
LD_LIBRARY_PATH+=":${BASE_PATH}/pi-opendds/build/target/lib"
LD_LIBRARY_PATH+=":${BASE_PATH}/pi-openssl/usr/local/lib"
LD_LIBRARY_PATH+=":${BASE_PATH}/pi-xerces/lib"
LD_LIBRARY_PATH+=":${BASE_PATH}/pigpio/lib"
LD_LIBRARY_PATH+=":${BASE_PATH}/smartlock/Idl"
cert_dir=${BASE_PATH}/smartlock/certs
smartlock_ini=${BASE_PATH}/smartlock/smartlock.ini

SECURITY=${SMARTLOCK_SECURE:-0}
CMD=start
LOCK=
while (( $# > 0 )); do
    case "$1" in
        --security)
            SECURITY=1
            shift
            ;;
        -h|--help)
            echo "Usage: smartlock.sh [--security] [--lock LOCK_ID] start | stop | restart | start-system"
            exit
            ;;
        --lock)
            LOCK="$2"
            shift 2
            ;;
        start)
            CMD=start
            shift
            ;;
        stop)
            CMD=stop
            shift
            ;;
        restart)
            CMD=restart
            shift
            ;;
        start-system)
            CMD=start-system
            shift
            ;;
        *)
            echo "ERROR: invalid argument '$1' supplied"
            exit 1
            ;;
    esac
done

if [[ -z "$LOCK" ]]; then
    if [[ -f ${BASE_PATH}/smartlock.id ]]; then
        LOCK="$(cat ${BASE_PATH}/smartlock.id)"
    else
        echo "ERROR: must supply a valid lock identifier to --lock"
        exit
    fi
fi

ID_CA=${cert_dir}/id_ca/identity_ca.pem
ID_CERT=${cert_dir}/${LOCK}/identity.pem
ID_PKEY=${cert_dir}/${LOCK}/identity_key.pem
PERM_CA=${cert_dir}/perm_ca/permissions_ca.pem
PERM_GOV=${cert_dir}/governance.xml.p7s
PERM_PERMS=${cert_dir}/${LOCK}/permissions.xml.p7s

if (( $SECURITY )); then
    SECURITY_ARGS=" \
    -DCPSSecurityDebug bookkeeping \
    -DCPSSecurity 1 \
    -ID_CA ${ID_CA} \
    -ID_CERT ${ID_CERT} \
    -ID_PKEY ${ID_PKEY} \
    -PERM_CA ${PERM_CA} \
    -PERM_GOV ${PERM_GOV} \
    -PERM_PERMS ${PERM_PERMS} \
    "
fi

echo "CMD: '$CMD', SECURITY: '$SECURITY', LOCK_ID: '$LOCK', SECURITY_ARGS: '$SECURITY_ARGS'"

function update_certs {
  API_URL=$(grep api_url ${smartlock_ini} | sed 's/api_url *= *"//; s/".*//')
  USERNAME=$(grep username ${smartlock_ini} | sed 's/username *= *"//; s/".*//')
  PASSWORD=$(cat ${BASE_PATH}/dpm_password)
  NONCE=${LOCK}

  if ! command -v rustc &> /dev/null
  then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
  fi

  cd certs_downloader
  cargo build --release
  cargo run $API_URL $USERNAME $PASSWORD $NONCE $cert_dir $LOCK id_ca perm_ca
  cd ..
}

PID_FILE=${BASE_PATH}/smartlock.pid
start() {
    if (( $SECURITY )); then
      update_certs
    fi

    ${BASE_PATH}/smartlock/smartlock \
        -DCPSConfigFile ${BASE_PATH}/smartlock/rtps.ini \
        -DCPSDebugLevel 5 \
        -DCPSTransportDebugLevel 5 \
        -lock ${LOCK} \
        -ini ${smartlock_ini} \
        ${SECURITY_ARGS} &

    echo "$!" > $PID_FILE
}

stop() {
    if [[ -f "$PID_FILE" ]]; then
        kill -2 "$(cat $PID_FILE)"
        rm $PID_FILE
    fi
}

start-system() {
    if (( $SECURITY )); then
      update_certs
    fi
    export LD_LIBRARY_PATH
    exec ${BASE_PATH}/smartlock/smartlock \
        -DCPSConfigFile ${BASE_PATH}/smartlock/rtps.ini \
        -DCPSDebugLevel 5 \
        -DCPSTransportDebugLevel 5 \
        -lock ${LOCK} \
        -ini ${smartlock_ini} \
        ${SECURITY_ARGS}
}

case "$CMD" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    start-system)
        start-system
        ;;
    *)
        echo "ERROR: invalid command '$CMD'"
        exit 1
        ;;
esac
