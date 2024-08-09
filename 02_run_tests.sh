# create fio job file.
/bin/bash create_job_file.sh

job_info=job_info.txt
#at_time=$(date +%H:%M -d '5 mins')
platform=`grep "^platform" config.file | awk -F "=" '{print $2}'`

prepare_test () {
	/bin/bash initial_sfio_check.sh

	if [[ $(oc get pods | grep fio-client | awk '{print $1}') == "fio-client" ]];
        	then
        	oc delete pod fio-client
	elif [[ $(oc get pods | grep fio-prefill | awk '{print $1}') == "fio-prefill" ]];
                then
                oc delete pod fio-prefill
		oc delete cm fio-prefill-info fio-prefill-job
	fi

	oc get cm | egrep "fio-job-info|fio-test-job" > /dev/null
	if [ `echo $?` -eq 0 ]; then
        	oc delete configmap fio-job-info fio-test-job
	fi

	oc create configmap fio-job-info --from-file=${job_info}
	oc create configmap fio-test-job --from-file=job.fio
	
	#=======================================
	# OSD Cache drop and kernel cache drop
	#----------------------------------------
	#echo "Manually dropping Ceph OSD cache"
	#ceph tell osd.* cache drop
	#echo "Manually dropping Worker node kernel cache"
	#oc debug node/worker-001.t42lp39fo25gabhishek.lnxperf.boe -- sync; echo 3 > /proc/sys/vm/drop_caches
	#oc debug node/worker-002.t42lp39fo25gabhishek.lnxperf.boe -- sync; echo 3 > /proc/sys/vm/drop_caches
	#oc debug node/worker-003.t42lp39fo25gabhishek.lnxperf.boe -- sync; echo 3 > /proc/sys/vm/drop_caches
	
}

if [ $platform == "bm" ]; then
	prepare_test
elif [ $platform == "hcp" ]; then
	for consumer in $(cat consumers.lst)
	do
		oc config use $consumer
		prepare_test
	done
fi
if [ $platform == "bm" ]; then
	oc create -f client.yaml
elif [ $platform == "hcp" ]; then
	for consumer in $(cat consumers.lst)
	do
		oc create -f client.yaml --context ${consumer}
	done
fi

rm -f ${job_info} 
rm -f job.fio
