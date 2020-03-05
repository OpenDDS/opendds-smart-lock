#!/bin/bash
#
# Usage: ./smartlock.sh lock1

LD_LIBRARY_PATH+="${LD_LIBRARY_PATH+:}/home/pi/pi-opendds/build/target/ACE_TAO/ACE/lib"
LD_LIBRARY_PATH+=":/home/pi/pi-opendds/build/target/lib"
LD_LIBRARY_PATH+=":/home/pi/pi-openssl/usr/local/lib"
LD_LIBRARY_PATH+=":/home/pi/pi-xerces/lib"
LD_LIBRARY_PATH+=":/home/pi/smartlock/Idl"
cert_dir=/home/pi/smartlock/certs

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
    if [[ -f /home/pi/smartlock.id ]]; then
        LOCK="$(cat /home/pi/smartlock.id)"
    else
        echo "ERROR: must supply a valid lock identifier to --lock"
        exit
    fi
fi

if (( $SECURITY )); then
    SECURITY_ARGS=" \
    -DCPSSecurityDebug bookkeeping \
    -DCPSSecurity 1 \
	-ID_CA ${cert_dir}/id_ca/identity_ca_cert.pem \
	-ID_CERT ${cert_dir}/${LOCK}/${LOCK}_cert.pem \
	-ID_PKEY ${cert_dir}/${LOCK}/private_key.pem \
	-PERM_CA ${cert_dir}/perm_ca/permissions_ca_cert.pem \
	-PERM_GOV ${cert_dir}/gov_signed.p7s \
	-PERM_PERMS ${cert_dir}/${LOCK}/house1_signed.p7s \
    "
fi

echo "CMD: '$CMD', SECURITY: '$SECURITY', LOCK_ID: '$LOCK', SECURITY_ARGS: '$SECURITY_ARGS'"

PID_FILE=/home/pi/smartlock.pid
start() {
    /home/pi/smartlock/smartlock \
        -DCPSConfigFile /home/pi/smartlock/rtps.ini \
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
    export LD_LIBRARY_PATH
    exec /home/pi/smartlock/smartlock \
        -DCPSConfigFile /home/pi/smartlock/rtps.ini \
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
