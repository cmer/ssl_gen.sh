#!/bin/bash
#
#
# Script to generate a Certificate Authority and SSL certificate signed with it.
#
#
# Inspired in part by https://rogerhub.com/~r/code.rogerhub/infrastructure/474/signing-your-own-wildcard-sslhttps-certificates/
#
#

CA_NAME="Acme Authority"
DOMAIN=example.org
COUNTRY=CA
STATE=ON
CITY=Toronto
DAYS=825  # Notes: Newer OS will not accept a server certificate that is valid for more than 825 days.

function usage()
{
   cat << HEREDOC

   Usage: ssl_gen.sh

   optional arguments:
     -h, --help           show this help message and exit
     -a, --auto           automated mode: skips all user prompts
         --overwrite-ca   overwrite existing certificate authority
         --skip-ca        skip certificate authority generation
         --skip-cert      skip certificate generation

HEREDOC
}

auto=0
skip_ca=0
skip_cert=0
overwrite_ca=0
ca_exists=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -a|--auto) auto=1; shift ;;
        --overwrite-ca) overwrite_ca=1; shift ;;
        --skip-ca) skip_ca=1; shift ;;
        --skip-cert) skip_cert=1; shift ;;
        -h|--help) usage; exit 1 ;;
        *) printf "   Unknown parameter passed: $1\n"; usage ; exit 1 ;;
    esac
    shift
done

if [ -f "rootCA.key" ]; then
  ca_exists=1
fi

printf ""

if [[ $ca_exists -eq 1 && $overwrite_ca -eq 0 ]]; then
  printf "* Will skip Certificate Authority generation because it already exists.\n\n"
  skip_ca=1
fi

if [ $auto -eq 0 ]; then
  if [ $skip_ca -eq 0 ]; then
    read -p "Certificate Authority Name [$CA_NAME]: " input  ;  CA_NAME=${input:-$CA_NAME}
  fi

  if [ $skip_cert -eq 0 ]; then
    read -p "Certificate Domain [$DOMAIN]: " input             ;  DOMAIN=${input:-$DOMAIN}
    read -p "Country [$COUNTRY]: " input                       ;  COUNTRY=${input:-$COUNTRY}
    read -p "State [$STATE]: " input                           ;  STATE=${input:-$STATE}
    read -p "City [$CITY]: " input                             ;  CITY=${input:-$CITY}
    read -p "Admin Email [root@$DOMAIN]: " input                             ;  EMAIL=${input:-root@$DOMAIN}
    read -p "Days until expiration (max 825) [$DAYS]: " input  ;  DAYS=${input:-$DAYS}
  fi
fi

if [ $skip_ca -eq 0 ]; then
  openssl genrsa -out rootCA.key 2048
  openssl req -x509 -sha256 -new -nodes -key rootCA.key -days 9999 -out rootCA.pem -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=./CN=$CA_NAME" # OK to ignore `Can't load /root/.rnd into RNG` error message
  openssl genrsa -out host.key 2048
fi

if [ $skip_cert -eq 0 ]; then
  echo "[req_distinguished_name]
  countryName = $COUNTRY
  stateOrProvinceName = $STATE
  localityName = $CITY
  organizationalUnitName = .
  commonName = $DOMAIN
  emailAddress = $EMAIL

  [req]
  distinguished_name = req_distinguished_name
  req_extensions = v3_req
  prompt = no

  [v3_req]
  extendedKeyUsage = serverAuth
  subjectAltName = @alt_names

  [alt_names]
  DNS.1 = $DOMAIN
  DNS.2 = *.$DOMAIN" > host.cnf

  openssl req -sha256 -new -key host.key -out host.csr -config host.cnf
  openssl x509 -req -sha256 -days $DAYS -in host.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -extensions v3_req -out host.crt -extfile host.cnf
fi

printf "\nDone!\n\n"

if [ $skip_ca -eq 0 ]; then
  printf "CA: rootCA.key rootCA.pem rootCA.srl host.key\n"
fi

if [ $skip_cert -eq 0 ]; then
  printf "CERT: host.crt\n"
fi

