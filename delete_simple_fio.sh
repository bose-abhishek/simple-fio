#!/bin/bash

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
