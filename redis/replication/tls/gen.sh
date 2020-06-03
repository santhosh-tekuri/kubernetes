#!/usr/bin/env bash

set -e
cd "$(dirname "${BASH_SOURCE[0]}")"
openssl req -x509 -new -keyout tls.key -nodes -out tls.crt -subj '/C=XX/ST=XX/O=XX/CN=XX' -days 900000
openssl dhparam -out tls.dh 2048
