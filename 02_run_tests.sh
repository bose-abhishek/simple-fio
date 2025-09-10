#!/bin/bash
set -euo pipefail

# Validate required tools and files
command -v oc >/dev/null 2>&1 || { echo "ERROR: oc command not found" >&2; exit 1; }
[[ -f "config.file" ]] || { echo "ERROR: config.file not found" >&2; exit 1; }
[[ -f "create_job_file.sh" ]] || { echo "ERROR: create_job_file.sh not found" >&2; exit 1; }

echo "Creating FIO job file..."
/bin/bash create_job_file.sh

job_info="job_info.txt"
#at_time=$(date +%H:%M -d '5 mins')
platform=$(grep "^platform" config.file | awk -F "=" '{print $2}')

prepare_test () {
	echo "Preparing test environment"
	
	# Clean up existing fio-client pod if it exists
	if oc get pod fio-client >/dev/null 2>&1; then
		echo "Deleting existing fio-client pod"
		oc delete pod fio-client --ignore-not-found=true
		oc wait --for=delete pod/fio-client --timeout=60s 2>/dev/null || true
	fi
	
	# Clean up existing fio-prefill pod if it exists
	if oc get pod fio-prefill >/dev/null 2>&1; then
		echo "Deleting existing fio-prefill pod"
		oc delete pod fio-prefill --ignore-not-found=true
		oc wait --for=delete pod/fio-prefill --timeout=60s 2>/dev/null || true
		# Clean up associated configmaps
		oc delete cm fio-prefill-info fio-prefill-job --ignore-not-found=true
	fi

	# Clean up existing configmaps
	if oc get cm | grep -E "fio-job-info|fio-test-job" >/dev/null 2>&1; then
		echo "Deleting existing configmaps"
		oc delete configmap fio-job-info fio-test-job --ignore-not-found=true
	fi

	# Validate required files exist before creating configmaps
	[[ -f "$job_info" ]] || { echo "ERROR: $job_info not found" >&2; exit 1; }
	[[ -f "job.fio" ]] || { echo "ERROR: job.fio not found" >&2; exit 1; }
	[[ -f "fio-svc.yaml" ]] || { echo "ERROR: fio-svc.yaml not found" >&2; exit 1; }

	echo "Creating configmaps"
	oc create configmap fio-job-info --from-file="$job_info"
	oc create configmap fio-test-job --from-file=job.fio

	echo "Creating FIO service"
	oc create -f fio-svc.yaml
	
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
	for consumer in $(cat hcp_consumers.lst)
	do
		oc config use $consumer
		prepare_test
	done < "$consumer_file"
else
	echo "ERROR: Unknown platform '$platform'. Expected 'bm' or 'hcp'" >&2
	exit 1
fi
if [ $platform == "bm" ]; then
	oc create -f client.yaml
elif [ $platform == "hcp" ]; then
	for consumer in $(cat hcp_consumers.lst)
	do
		oc create -f client.yaml --context ${consumer}
	done
fi

# Clean up temporary files
rm -f "$job_info" 
rm -f job.fio

echo "FIO test started successfully!"
