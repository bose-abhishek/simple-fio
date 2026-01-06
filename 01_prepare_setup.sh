#!/bin/bash
set -euo pipefail

# Validate required tools and files
command -v oc >/dev/null 2>&1 || { echo "ERROR: oc command not found" >&2; exit 1; }
[[ -f "config.file" ]] || { echo "ERROR: config.file not found" >&2; exit 1; }

/bin/bash create_job_file.sh
namespace="simple-fio"
server=$(grep "^server" config.file | awk -F "=" '{print $2}')
storage=$(grep "^storage(Gi)" config.file | awk -F "=" '{print $2}')
storage_class=$(grep "^storageclass" config.file | awk -F "=" '{print $2}')
volume_mode=$(grep "^volumemode" config.file | awk -F "=" '{print $2}')
platform=$(grep "^platform" config.file | awk -F "=" '{print $2}')
unit=$(grep "^unit" config.file | awk -F "=" '{print $2}')

#export sample=${sample}
export storage=${storage}
#export storage_type=${storage_type}
#export prefill=${prefill}

pfile=prefill.fio
job_info=job_info.txt

setup () {
	/bin/bash preflight_check.sh

	/bin/bash delete.sh --test

	namespace=${namespace}
	server_ip=server_ip.txt
	> $server_ip
	
	if [[ "$unit" == "vm" ]]; then
		#if ! oc get hco -A >/dev/null 2>&1; then
        		create_vms
		#else 
		#	echo "Openshift Virtualization is not installed or configured properly"
		#	exit 
		#fi


		#for ((i=0;i<$server;i++));
		#do
			serverIP=$(oc get svc -l app=simple-fio -ojsonpath='{.items[?(@.metadata.name!="fio-pod-service")].spec.clusterIP}')
			echo "$serverIP" >> "$server_ip"
		#done

	elif [ $unit == "pod" ]; then
		for ((i=0;i<$server;i++));
		do
		export srv=${i}
		if [[ ${volume_mode} =~ "Block" ]]; then
			sc=${storage_class}
			export sc=${sc}
			envsubst < blk-pvc.yaml | oc create -f -
			sleep 20
			envsubst < blk-server.yaml | oc create -f -

		elif [[ ${volume_mode} =~ "Filesystem" ]]; then
			sc=${storage_class}
			export sc=${sc}
			envsubst < fs-pvc.yaml | oc create -f -
			sleep 20
			envsubst < fs-server.yaml | oc create -f -
		fi

		oc wait pod --for=condition=Ready -l app=fio-server --timeout=1h > /dev/null
		pod=`echo fio-server${i}`

		serverIP=`oc get pod ${pod} -n ${namespace} --template '{{.status.podIP}}'`
		echo $serverIP >> $server_ip
	done
	oc get pvc
	fi
	oc create configmap fio-server-ip --from-file=${server_ip}
	sleep 10

	prefill=`grep "^prefill" config.file | awk -F "=" '{print $2}'`

	if [[ $prefill == "true" ]]; then
		oc create configmap fio-prefill-job --from-file=${pfile}
		oc create configmap fio-prefill-info --from-file=${job_info}
		oc create -f prefill.yaml
	#	oc wait pod --for=condition=Ready -l app=fio-prefill --timeout=1h > /dev/null
	fi
}

create_vms () {
#oc create ns migration-vms > /dev/null
#oc project migration-vms 2> /dev/null

numOfVms=`grep "^server" config.file | awk -F "=" '{print $2}'`

# Create VMs (mention number of VMs)
python3 create_vms.py ${numOfVms}
python3 create_svcs.py ${numOfVms}
echo "$(date): All VM creation started"
sleep 30
while true;
do
	if [ "$(oc get vm -ojson | jq -r .items[].status.printableStatus | sort | tail -n1)" != "Running" ];
	then
		echo "$(date): waiting for all VMs to be in running state"
		sleep 60
	else
		echo "$(date): All VMs are in Running state"
		break;
	fi
done

# To check all prime PVCs have been deleted before proceeding with the migration.
echo "Waiting for prime PVCs to be deleted..."
timeout=600  # 10 minutes timeout
elapsed=0
while [ $elapsed -lt $timeout ]; do
	if ! oc get pvc -oname 2>/dev/null | grep -q prime; then
		echo "All prime PVCs have been deleted."
		break
	fi
	echo "Prime PVCs still exist, waiting... (${elapsed}s/${timeout}s)"
	sleep 30
	elapsed=$((elapsed + 30))
done

if [ $elapsed -ge $timeout ]; then
	echo "ERROR: Timeout waiting for prime PVCs to be deleted" >&2
	exit 1
fi
}


if [ $platform == "bm" ]; then
	setup
elif [ $platform == "hcp" ]; then
	# Switch to the main / base / provider cluster
	oc config use admin
	for consumer in $(cat hcp_consumers.lst)
	do
		oc config use $consumer
		setup
		#oc get pods
	done

fi
rm -f ${server_ip} ${pfile} ${job_info}
rm -f ${pfile}
#---------------
# End of script
#---------------
