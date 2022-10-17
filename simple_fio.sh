#!/bin/bash
#
#==========================================================
# Creating and setting up the namespace
# ---------------------------------------------------------
namespace="simple-fio"
if [ `oc get project | grep ${namespace} | awk '{print $1}'` ]
then 
	oc project ${namespace}
else
	oc create namespace ${namespace}
	oc project ${namespace}

fi

#=========================================================
# Creating the fio job file from config
#---------------------------------------------------------
file=job.fio
pfile=prefill.fio

echo "[global]" > ${file}

echo "ioengine=libaio" >> ${file}

grep "^direct" config.file >> ${file}

grep "^numjobs" config.file >> ${file}

grep "^size" config.file >> ${file}

if [ `grep storage_type config.file | awk -F "=" '{print $2}'` == "ocs-storagecluster-ceph-rbd" ]; then
	echo "filename=/dev/rbd" >> ${file}
elif [ `grep storage_type config.file | awk -F "=" '{print $2}'` == "ocs-storagecluster-cephfs" ]; then
	echo "directory=/mnt/pvc" >> ${file}
else
	echo "Job file not configured properly as storage_type in config file is unknown"
fi

echo "" >> ${file}
cp ${file} ${pfile}

echo -e "[fio_test] \ntime_based=0 \nrw=write \nbs=128K \niodepth=1 \ngroup_reporting" >> ${pfile}

echo -e "[fio_test]" >> ${file}
grep "^rw" config.file >> ${file}
grep "^bs" config.file >> ${file}
grep "^time_based" config.file >> ${file}
grep "^runtime" config.file >> ${file}
grep "^iodepth" config.file >> ${file}
echo "group_reporting" >> ${file}

#==========================================================
# Create fio server and client pods
#----------------------------------------------------------
server=`grep server config.file | awk -F "=" '{print $2}'`
sample=`grep sample config.file | awk -F "=" '{print $2}'`
storage=`grep "storage(Gi)" config.file | awk -F "=" '{print $2}'`
fio_args_prefill=""
fio_args_job=""

export sample=${sample}
export storage=${storage}

for ((i=0;i<$server;i++));
do
	export srv=${i}
	if [ `grep storage_type config.file | awk -F "=" '{print $2}'` == "ocs-storagecluster-ceph-rbd" ]; then
		envsubst < blk-pvc.yaml | oc create -f -
		sleep 20
		envsubst < blk-server.yaml | oc create -f -
	elif [ `grep storage_type config.file | awk -F "=" '{print $2}'` == "ocs-storagecluster-cephfs" ]; then
		envsubst < fs-pvc.yaml | oc create -f -
		sleep 20
		envsubst < fs-server.yaml | oc create -f -
	fi
	sleep 20
	pod=`echo fio-server${i}`
	oc cp job.fio ${namespace}/${pod}:/tmp/
	oc cp prefill.fio ${namespace}/${pod}:/tmp/
done

for ((i=0;i<$server;i++));
do
	pod=`echo fio-server${i}`
	serverIP=`oc get pod ${pod} -n ${namespace} --template '{{.status.podIP}}'`
	fio_args_prefill=`echo ${fio_args_prefill} --client=${serverIP} --remote-config /tmp/prefill.fio `
	#fio_args_prefill=`echo ${fio_args_prefill} --client=ip6:${serverIP} --remote-config /tmp/prefill.fio `
	fio_args_job=`echo ${fio_args_job} --client=${serverIP} --remote-config /tmp/job.fio `
	#fio_args_job=`echo ${fio_args_job} --client=ip6:${serverIP} --remote-config /tmp/job.fio `
	sleep 20
done

#echo ${fio_args_prefill}
#echo ${fio_args_job}

echo ${fio_args_prefill} > fio_args_prefill
echo ${fio_args_job} > fio_args_job

export fio_args_prefill=$(cat fio_args_prefill)
export fio_args_job=$(cat fio_args_job)

sleep 10
envsubst < client.yaml | oc create -f -

rm -f fio_args_prefill
#rm -f fio_args_job

#---------------
# End of script
#---------------
