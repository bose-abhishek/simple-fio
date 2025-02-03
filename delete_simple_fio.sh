#!/bin/bash

<<<<<<< HEAD
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
=======
namespace=simple-fio
platform=`grep "^platform" config.file | awk -F "=" '{print $2}'`

delete_setup () {

        oc project ${namespace}
        
        oc get cm | grep fio
        if [ `echo $?` -eq 0 ]; then
                for cm in $(oc get cm -oname | grep fio); do oc delete $cm; done
        fi
        
        oc get pods | grep fio-server
        if [ `echo $?` -eq 0 ]; then
                for pod in $(oc get pods -oname | grep fio-server); do oc delete $pod; done
        fi
        
        if [[ $(oc get pods | grep fio-client | awk '{print $1}') == "fio-client" ]];
                then
                oc delete pod fio-client
        fi
        
        if [[ $(oc get pods | grep fio-prefill | awk '{print $1}') == "fio-prefill" ]];
                then
                oc delete pod fio-prefill
        fi
        
        oc get pvc | grep fio-pv-claim
        if [ `echo $?` -eq 0 ]; then
                for pvc in $(oc get pvc -oname | grep fio-pv-claim); do oc delete $pvc; done
        fi
}

if [ $platform == "bm" ]; then
        delete_setup
elif [ $platform == "hcp" ]; then
        for consumer in $(cat consumers.lst)
        do
#                oc config use $consumer
                delete_setup
        done

fi
>>>>>>> source/main
