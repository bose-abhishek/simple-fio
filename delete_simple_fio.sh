#!/bin/bash

server=`grep server config.file | awk -F "=" '{print $2}'`
device_type=`grep "^storage_type" config.file | awk -F "=" '{print $2}'`

oc delete -f client.yaml

for ((i=0;i<$server;i++));
do
export srv=${i}
if [ ${device_type} == "ocs-storagecluster-ceph-rbd" ]; then
	envsubst < blk-server.yaml | oc delete -f -
	sleep 10
elif [ ${device_type} == "ocs-storagecluster-cephfs" ]; then
	envsubst < fs-server.yaml | oc delete -f -
	sleep 10
fi

envsubst < blk-pvc.yaml | oc delete -f -
done
