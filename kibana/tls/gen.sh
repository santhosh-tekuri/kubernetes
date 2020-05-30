#!/usr/bin/env bash

set -e
cd "$(dirname "${BASH_SOURCE[0]}")"
openssl req -x509 -new -keyout key -nodes -out cert -subj '/C=XX/ST=XX/O=XX/CN=XX' -days 900000
