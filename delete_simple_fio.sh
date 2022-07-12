#!/bin/bash

server=`grep server config.file | awk -F "=" '{print $2}'`
oc delete -f fio.yaml
for ((i=0;i<$server;i++));
do
export srv=${i}
envsubst < server.yaml | oc delete -f -
sleep 10
envsubst < blk-pvc.yaml | oc delete -f -
done

