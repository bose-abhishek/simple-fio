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
echo "[global]" > ${file}
echo "ioengine=libaio" >> ${file}
tail -n +20 config.file >> ${file}
echo "" >> ${file}
echo "[device]" >> ${file}
if [ `grep storage_type config.file | awk -F "=" '{print $2}'` == "ocs-storagecluster-ceph-rbd" ]; then
	echo "filename=/dev/rbd0" >> ${file}
elif [ `grep storage_type config.file | awk -F "=" '{print $2}'` == "ocs-storagecluster-cephfs" ]; then
	echo "directory=/mnt/pvc" >> ${file}
else
	echo "Job file not configured properly as storage_type in config file is unknown"
fi

#==========================================================
# Create fio server and client pods
#----------------------------------------------------------
server=`grep server config.file | awk -F "=" '{print $2}'`
sample=`grep sample config.file | awk -F "=" '{print $2}'`
storage=`grep "storage(Gi)" config.file | awk -F "=" '{print $2}'`
final_serverIPs=""

export sample=${sample}
export storage=${storage}
#> final_serverIPs
for ((i=0;i<$server;i++));
do
	export srv=${i}
	envsubst < blk-pvc.yaml | oc create -f -
	sleep 10
	envsubst < server.yaml | oc create -f -
	sleep 10
	pod=`echo fio-server${i}`
	oc cp job.fio ${namespace}/${pod}:/tmp/
done
for ((i=0;i<$server;i++));
do
	pod=`echo fio-server${i}`
	serverIP=`oc get pod ${pod} --template '{{.status.podIP}}'`
	final_serverIPs=`echo ${final_serverIPs} --client=${serverIP} --remote-config /tmp/job.fio `
done

echo ${final_serverIPs} > final_serverIPs
export final_serverIPs=$(cat final_serverIPs)
sleep 10
envsubst < fio.yaml | oc create -f -
rm -f final_serverIPs

#---------------
# End of script
#---------------
