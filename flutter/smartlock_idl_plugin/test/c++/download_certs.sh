#!/bin/bash

APP_PASSWORD=$1

cert_dir=certs
LOCK=lock1

ID_CA=${cert_dir}/id_ca/identity_ca.pem
ID_CERT=${cert_dir}/${LOCK}/identity.pem
ID_PKEY=${cert_dir}/${LOCK}/identity_key.pem
PERM_CA=${cert_dir}/perm_ca/permissions_ca.pem
PERM_GOV=${cert_dir}/governance.xml.p7s
PERM_PERMS=${cert_dir}/${LOCK}/permissions.xml.p7s

function update_certs {
  APP_NONCE=${LOCK1}

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

update_certs
