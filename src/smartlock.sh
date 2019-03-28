#!/bin/bash
#
# Usage: ./smartlock.sh lock1

source /home/pi/pi-opendds/build/target/setenv.sh
LD_LIBRARY_PATH+=":/home/pi/pi-openssl/usr/local/lib"
LD_LIBRARY_PATH+=":/home/pi/pi-xerces/lib"
LD_LIBRARY_PATH+=":/home/pi/SmartLock/Idl"
dir=/home/pi/certs

SECURITY=0
CMD=start
LOCK=
while (( $# > 0 )); do
    case "$1" in
        --security)
            SECURITY=1
            shift
            ;;
        -h|--help)
            echo "Usage: smartlock.sh [--security] --lock LOCK_ID start | stop | restart"
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
        *)
            echo "ERROR: invalid argument '$1' supplied"
            exit 1
            ;;
    esac
done

if [[ -z "$LOCK" ]]; then
    echo "ERROR: must supply a valid lock identifier to --lock"
    exit
fi

if (( $SECURITY )); then
    SECURITY_ARGS=" \
    -DCPSSecurity 1 \
	-ID_CA ${dir}/identity_ca_cert.pem \
	-ID_CERT ${dir}/${LOCK}/${LOCK}_cert.pem \
	-ID_PKEY ${dir}/${LOCK}/private_key.pem \
	-PERM_CA ${dir}/permissions_ca_cert.pem \
	-PERM_GOV ${dir}/gov_signed.p7s \
	-PERM_PERMS ${dir}/${LOCK}/house1_signed.p7s
    "
fi

echo "CMD: '$CMD', SECURITY: '$SECURITY', LOCK_ID: '$LOCK', SECURITY_ARGS: '$SECURITY_ARGS'"

PID_FILE=/home/pi/smartlock-${LOCK}.pid
start() {
    /home/pi/SmartLock/smartlock \
        -DCPSConfigFile /home/pi/SmartLock/rtps.ini \
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
    *)
        echo "ERROR: invalid command '$CMD'"
        exit 1
        ;;
esac

