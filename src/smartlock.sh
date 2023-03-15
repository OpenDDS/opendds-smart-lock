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
  APP_PASSWORD=$(cat ${BASE_PATH}/dpm_password)
  APP_NONCE='lock'

  mkdir -p ${cert_dir}/id_ca ${cert_dir}/${LOCK} ${cert_dir}/perm_ca

  curl -c cookies.txt -H'Content-Type: application/json' -d"{\"username\":\"54\",\"password\":\"$APP_PASSWORD\"}" https://dpm.unityfoundation.io/api/login

  curl --silent -b cookies.txt "https://dpm.unityfoundation.io/api/applications/identity_ca.pem" > ${ID_CA}
  curl --silent -b cookies.txt "https://dpm.unityfoundation.io/api/applications/permissions_ca.pem" > ${PERM_CA}
  curl --silent -b cookies.txt "https://dpm.unityfoundation.io/api/applications/governance.xml.p7s" > ${PERM_GOV}
  curl --silent -b cookies.txt "https://dpm.unityfoundation.io/api/applications/key_pair?nonce=${APP_NONCE}" > key-pair
  curl --silent -b cookies.txt "https://dpm.unityfoundation.io/api/applications/permissions.xml.p7s?nonce=${APP_NONCE}" > ${PERM_PERMS}

  jq -r '.public' key-pair > ${ID_CERT}
  jq -r '.private' key-pair > ${ID_PKEY}

  rm -f cookies.txt key-pair
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
        -groups house1 \
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
        -groups house1 \
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

