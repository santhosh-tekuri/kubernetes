#!/usr/bin/env bash

# zkOk.sh uses the ruok ZooKeeper four letter work to determine if the instance
# is health. The $? variable will be set to 0 if server responds that it is 
# healthy, or 1 if the server fails to respond.

ZK_CLIENT_PORT=${ZK_CLIENT_PORT:-2181}
OK=$(echo ruok | nc 127.0.0.1 $ZK_CLIENT_PORT)
if [ "$OK" == "imok" ]; then
    exit 0
else
    exit 1
fi
