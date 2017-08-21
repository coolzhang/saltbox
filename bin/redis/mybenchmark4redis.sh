#!/bin/bash
#  by Salvatore Sanfilippo
#

BIN=redis-benchmark
payload=32
iterations=100000
keyspace=100000
port=7000
logfile=/tmp/redis_benchmark.log

for clients in 1 5 10 20 30 40 50 60 70 80 90 100 200 300
do
    SPEED=0
    for dummy in 0 1 2
    do
        S=$($BIN -p $port -n $iterations -r $keyspace -d $payload -c $clients -t get | grep 'per second' | tail -1 | cut -f 1 -d'.')
        if [ $(($S > $SPEED)) != "0" ]
        then
            SPEED=$S
        fi
    done
    echo "$clients $SPEED" >> $logfile
done
