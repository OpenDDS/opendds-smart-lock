#
# Usage: smartlock.sh --security --lock 1 start-system

EXEC_PATH="/usr/bin"
CONFIG_PATH="/etc/smartlock"
STATE_PATH="/var/run"

cert_dir=${CONFIG_PATH}/certs
smartlock_ini=${CONFIG_PATH}/smartlock.ini

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
    if [[ -f ${CONFIG_PATH}/smartlock.id ]]; then
        LOCK="$(cat ${CONFIG_PATH}/smartlock.id)"
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
  APP_PASSWORD=$(cat ${CONFIG_PATH}/dpm_password)
  APP_NONCE=${LOCK}
  API_URL=$(grep api_url ${smartlock_ini} | sed 's/api_url *= *"//; s/".*//')
  USERNAME=$(grep username ${smartlock_ini} | sed 's/username *= *"//; s/".*//')

  mkdir -p ${cert_dir}/id_ca ${cert_dir}/${LOCK} ${cert_dir}/perm_ca

  curl -c cookies.txt -H'Content-Type: application/json' -d"{\"username\":\"${USERNAME}\",\"password\":\"$APP_PASSWORD\"}" ${API_URL}/login

  curl --silent -b cookies.txt "${API_URL}/applications/identity_ca.pem" > ${ID_CA}
  curl --silent -b cookies.txt "${API_URL}/applications/permissions_ca.pem" > ${PERM_CA}
  curl --silent -b cookies.txt "${API_URL}/applications/governance.xml.p7s" > ${PERM_GOV}
  curl --silent -b cookies.txt "${API_URL}/applications/key_pair?nonce=${APP_NONCE}" > key-pair
  curl --silent -b cookies.txt "${API_URL}/applications/permissions.xml.p7s?nonce=${APP_NONCE}" > ${PERM_PERMS}

  jq -r '.public' key-pair > ${ID_CERT}
  jq -r '.private' key-pair > ${ID_PKEY}

  rm -f cookies.txt key-pair
}

PID_FILE=${STATE_PATH}/smartlock.pid

start() {
    if (( $SECURITY )); then
      update_certs
    fi

    ${EXEC_PATH}/smartlock \
        -DCPSConfigFile ${CONFIG_PATH}/rtps.ini \
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

start_system() {
    if (( $SECURITY )); then
      update_certs
    fi
    ${EXEC_PATH}/smartlock \
        -DCPSConfigFile ${CONFIG_PATH}/rtps.ini \
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
        start_system
        ;;
    *)
        echo "ERROR: invalid command '$CMD'"
        exit 1
        ;;
esac
