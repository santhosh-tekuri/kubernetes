#!/usr/bin/env bash

set -e

cd /kafka

cp /configtmp/server.properties config/server.properties

HOST=$(hostname -s)
DOMAIN=$(hostname -d)
if [[ $HOST =~ (.*)-([0-9]+)$ ]]; then
    NAME=${BASH_REMATCH[1]}
    ORD=${BASH_REMATCH[2]}
else
    echo "Failed to parse hostname $HOST"
    exit 1
fi

# update broker.id value
sed -i "s/^broker.id=.*/broker.id=$((ORD+1))/g" config/server.properties

# replace ${HOSTNAME}
sed -i "s/\${HOSTNAME}/$HOST.$DOMAIN/g" config/server.properties

exec "$@"
