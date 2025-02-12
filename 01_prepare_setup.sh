#!/bin/bash

/bin/bash create_job_file.sh

server=`grep "^server" config.file | awk -F "=" '{print $2}'`
storage=`grep "^storage(Gi)" config.file | awk -F "=" '{print $2}'`
storage_class=`grep "^storageclass" config.file | awk -F "=" '{print $2}'`
volume_mode=`grep "^volumemode" config.file | awk -F "=" '{print $2}'`
platform=`grep "^platform" config.file | awk -F "=" '{print $2}'`

#export sample=${sample}
export storage=${storage}
#export storage_type=${storage_type}
#export prefill=${prefill}

pfile=prefill.fio
job_info=job_info.txt

run_test () {
	/bin/bash preflight_check.sh

	/bin/bash delete_simple_fio.sh

	namespace="simple-fio"
	server_ip=server_ip.txt
	> $server_ip

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

if [ $platform == "bm" ]; then
	run_test
elif [ $platform == "hcp" ]; then
	# Switch to the main / base / provider cluster
	oc config use admin
	for consumer in $(cat consumers.lst)
	do
		oc config use $consumer
		run_test
		#oc get pods
	done

fi
rm -f ${server_ip} ${pfile} ${job_info}
rm -f ${pfile}
#---------------
# End of script
#---------------
