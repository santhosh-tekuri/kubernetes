#!/usr/bin/env bash

set -e
cd "$(dirname "${BASH_SOURCE[0]}")"
password=secret
rm -f keystore truststore
keytool -genkey -keyalg RSA -alias cassandra -keystore keystore -validity 900000 -storepass "$password" -keypass "$password" -dname "CN=None, OU=None, O=None, L=None, C=None"
keytool -export -alias cassandra -file cert.der -keystore keystore -storepass "$password"
keytool -import -v -trustcacerts -alias cassandra -file cert.der -keystore truststore -storepass "$password" -noprompt
openssl x509 -inform der -in cert.der -out cert.pem
rm cert.der
