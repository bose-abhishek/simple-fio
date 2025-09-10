#!/bin/bash

namespace=simple-fio
platform=`grep "^platform" config.file | awk -F "=" '{print $2}'`
unit=`grep "^unit" config.file | awk -F "=" '{print $2}'`

delete_test () {

        oc project ${namespace} > /dev/null 2>&1

        if [[ $(oc get pods | grep fio-client | awk '{print $1}') == "fio-client" ]];
                then
                oc delete pod fio-client
        fi

        if [[ $(oc get pods | grep fio-prefill | awk '{print $1}') == "fio-prefill" ]];
                then
                oc delete pod fio-prefill
        fi

	if oc get cm 2> /dev/null | grep -q prefill; then
		for cm in $(oc get cm -oname | grep prefill); do oc delete $cm; done
	fi

        if oc get svc 2>/dev/null | grep -q fio-pod-service; then
                for svc in $(oc get svc -oname | grep fio-pod-service); do oc delete $svc; done
        fi
}

delete_setup () {

        oc project ${namespace} > /dev/null 2>&1
        
        if oc get cm 2>/dev/null | grep -q fio; then
                for cm in $(oc get cm -oname | grep fio); do oc delete $cm; done
        fi
        
        if oc get pods 2>/dev/null | grep -q fio-server; then
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
        
        if oc get pvc -oname 2>/dev/null | grep -q fio-pv-claim; then
                for pvc in $(oc get pvc -oname | grep fio-pv-claim); do oc delete $pvc; done
        fi

        if oc get svc 2>/dev/null | grep -q fio-pod-service; then
                for svc in $(oc get svc -oname | grep fio-pod-service); do oc delete $svc; done
        fi
}

nuke_project () {
	oc delete -f fio-storage.yaml
	oc project default > /dev/null 2>&1
	oc delete ns simple-fio
}

delete_test_main () {
if [ $platform == "bm" ]; then
        delete_test
elif [ $platform == "hcp" ]; then
        for consumer in $(cat consumers.lst)
        do
                oc config use $consumer
                delete_test
        done
fi
}

delete_setup_main () {
delete_test_main
if [ $unit == "vm" ]; then
	for vmi in $(oc get vmi -oname -n simple-fio); do oc -n simple-fio delete $vmi; done
	for vm in $(oc get vm -oname -n simple-fio); do oc -n simple-fio delete $vm; done
	for svc in $(oc get svc -oname -n simple-fio); do oc -n simple-fio delete $svc; done
fi

if [ $platform == "bm" ]; then
        delete_setup
elif [ $platform == "hcp" ]; then
        for consumer in $(cat consumers.lst)
        do
                oc config use $consumer
                delete_setup
        done

fi
}

delete_project_main () {
delete_setup_main
nuke_project
}


usage () {
	cat << EOF
This script is for deleting resources.
Usage:
--test: Delete all the test related config and fio client pod.
--setup: Delete all the fio server pods and VMs.
--project: Delete and clear the simple-fio project including all test data stored in fio-storage volume.
--help: Print this help message.
EOF
}

while [ $# -ge 0 ]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        --test)
		delete_test_main
		exit 0
            ;;
        --setup)
		delete_setup_main
		exit 0
            ;;
        --project)
		delete_project_main
		exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

