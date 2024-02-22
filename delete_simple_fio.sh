#!/bin/bash

server=`grep server config.file | awk -F "=" '{print $2}'`
storage_type=`grep "^storage_type" config.file | awk -F "=" '{print $2}'`

oc delete -f client.yaml

for ((i=0;i<$server;i++));
do
export srv=${i}
if [[ ${storage_type} =~ "ceph-rbd" ]]; then
	envsubst < blk-server.yaml | oc delete -f -
	sleep 10
elif [[ ${storage_type} =~ "cephfs" ]]; then
	envsubst < fs-server.yaml | oc delete -f -
	sleep 10
fi

envsubst < blk-pvc.yaml | oc delete -f -
done
