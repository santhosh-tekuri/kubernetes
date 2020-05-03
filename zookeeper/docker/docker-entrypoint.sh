#!/bin/bash

set -e

cd /apache-zookeeper-3.6.1-bin

if [[ ! -f "conf/zoo.cfg" ]]; then
    cp /config/zoo.cfg /apache-zookeeper-3.6.1-bin/conf/zoo.cfg
fi

HOST=$(hostname -s)
DOMAIN=$(hostname -d)
if [[ $HOST =~ (.*)-([0-9]+)$ ]]; then
    NAME=${BASH_REMATCH[1]}
    ORD=${BASH_REMATCH[2]}
else
    echo "Failed to parse ordinal from hostname $HOST"
    exit 1
fi

if [[ ! -f "conf/zoo.cfg.dynamic" ]]; then
    {
        for i in $(seq 1 $REPLICAS); do
		echo "server.$i=$NAME-$((i-1)).$DOMAIN:2888:3888;2181"
        done
    } > conf/zoo.cfg.dynamic
fi

if [[ ! -f "/data/myid" ]]; then
    MY_ID=$((ORD+1))
    echo $MY_ID > /data/myid
fi

exec "$@"
