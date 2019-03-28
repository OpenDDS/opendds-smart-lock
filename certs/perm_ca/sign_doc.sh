#!/bin/bash
if [ $# -eq 0 ]; then
  echo "Expecing document name as argument."
  exit -1;
fi


PREFIX=`echo ${1} | rev | cut -d '/' -f 1 | cut -d '.' -f 2- | rev`

if [ "$PREFIX" == "" ]; then
  echo "Unable to determine document prefix."
  exit -1;
fi

if [ ! -f ${1} ]; then
  echo "File '${1}' doesn't exist."
  exit -1;
fi

openssl smime -sign -in ${1} -text -out ${PREFIX}_signed.p7s -signer ../perm_ca/permissions_ca_cert.pem -inkey ../perm_ca/permissions_ca_private_key.pem

