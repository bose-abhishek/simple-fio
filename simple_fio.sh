#!/bin/bash
#
#==========================================================
# Creating and setting up the namespace
# ---------------------------------------------------------
namespace="simple-fio"
if [ `oc get project | grep ${namespace} | awk '{print $1}'` ]
then 
	oc project ${namespace} > /dev/null
else
	echo "Creating project simple-fio"
	oc create namespace ${namespace}
	oc project ${namespace}

fi

#============================
# Check fio storage pod is up
#----------------------------
if [[ $(oc get pvc | grep fio-data-pvc | awk '{print $1}') != "fio-data-pvc" ]];
        then
	sc_type=$(oc get sc | grep cephfs | awk '{print $1}')
	export sc_type=${sc_type}
	envsubst < fio-data-pvc.yaml | oc create -f -
        #oc create -f fio-data-pvc.yaml
fi
if [[ $(oc get pods | grep fio-storage | awk '{print $1}') != "fio-storage" ]];
        then
        oc apply -f fio-storage.yaml
fi

#=========================================================
# Creating the fio job file from config
#---------------------------------------------------------
pfile=prefill.fio
prefill=`grep "^prefill" config.file | awk -F "=" '{print $2}'`
iter=1
bs_range=()
wl_range=()

for wl in $(grep ^rw config.file | awk -F "=" '{print $2}');
do
	wl_range+=($wl)
done

for bs in $(grep ^bs config.file | awk -F "=" '{print $2}'); 
do
	bs_range+=($bs)
done

for workload in ${wl_range[@]};
do
for blocksize in ${bs_range[@]}; 
do

	file=job${iter}.fio
	echo "[global]" > ${file}
	echo "ioengine=libaio" >> ${file}
	grep "^direct" config.file >> ${file}
	grep "^numjobs" config.file >> ${file}
	grep "^size" config.file >> ${file}

	if [[ `grep "^storage_type" config.file | awk -F "=" '{print $2}'` =~ "ceph-rbd" ]]; then
		echo "filename=/dev/rbd" >> ${file}
	elif [[ `grep "^storage_type" config.file | awk -F "=" '{print $2}'` =~ "cephfs" ]]; then
		echo "directory=/mnt/pvc" >> ${file}
		prefill=false
	else
		echo "Job file not configured properly as storage_type in config file is unknown"
	fi

	echo "" >> ${file}

	if [[ $prefill == "true" ]]; then
		cp ${file} ${pfile}
		echo -e "[fio_test] \ntime_based=0 \nrw=write \nbs=256K \niodepth=1 \ncreate_on_open=1 \n fsync_on_close=1 \ngroup_reporting" >> ${pfile}
	fi


	echo -e "[fio_test]" >> ${file}
	echo "rw=${workload}" >> ${file}
	echo "bs=${blocksize}" >> ${file}
	grep "^time_based" config.file >> ${file}
	grep "^runtime" config.file >> ${file}
	grep "^iodepth" config.file >> ${file}
	
	job=${workload}
	# Additional FIO parameters based on job/workload
	# For write workload, the parameters have been imported from Benchmark Operator
	# For random workloads, the parameters have been imported from ODF QE CI job file
	#--------------------------------------------------------------------------------
	if [ $job == "write" ];
	then
        	echo "fsync_on_close=1" >> ${file}
        	echo "create_on_open=1" >> ${file}
	elif [[ $job =~ ^[rand*] ]];
	then
        	echo "randrepeat=0" >> ${file}
        	echo "allrandrepeat=0" >> ${file}
	fi
	#-------------------------------------------------------------------------------
	grep "^log_avg_msec" config.file >> ${file}
	echo -e "write_iops_log=iops" >> ${file}
	echo -e "write_lat_log=latency" >> ${file}
	echo "group_reporting" >> ${file}
	iter=$(($iter+1))
done
done
#
#==========================================================
# Create fio server and client pods
#----------------------------------------------------------
server=`grep "^server" config.file | awk -F "=" '{print $2}'`
sample=`grep "^sample" config.file | awk -F "=" '{print $2}'`
storage=`grep "^storage(Gi)" config.file | awk -F "=" '{print $2}'`
storage_type=`grep "^storage_type" config.file | awk -F "=" '{print $2}'`
fio_args_prefill=""
fio_args_job=""
num_of_wl=${#wl_range[@]}
num_of_bs=${#bs_range[@]}

export sample=${sample}
export storage=${storage}
export storage_type=${storage_type}
export prefill=${prefill}
export num_of_wl=${num_of_wl}
export num_of_bs=${num_of_bs}

job_info=job_info.txt
> $job_info
echo "prefill=${prefill}" >> $job_info
echo "num_of_wl=${num_of_wl}" >> $job_info
echo "num_of_bs=${num_of_bs}" >> $job_info
echo "sample=${sample}" >> $job_info
echo "server=${server}" >> $job_info

server_ip=server_ip.txt
> $server_ip

for ((i=0;i<$server;i++));
do
	export srv=${i}
	if [[ `grep "^storage_type" config.file | awk -F "=" '{print $2}'` =~ "ceph-rbd" ]]; then
		envsubst < blk-pvc.yaml | oc create -f -
		sleep 20
		envsubst < blk-server.yaml | oc create -f -
		
	elif [[ `grep "^storage_type" config.file | awk -F "=" '{print $2}'` =~ "cephfs" ]]; then
		envsubst < fs-pvc.yaml | oc create -f -
		sleep 20
		envsubst < fs-server.yaml | oc create -f -
	fi

	oc wait pod --for=condition=Ready -l app=fio-server --timeout=1h > /dev/null
	pod=`echo fio-server${i}`

	serverIP=`oc get pod ${pod} -n ${namespace} --template '{{.status.podIP}}'`
	echo $serverIP >> $server_ip
done

sleep 10
oc create -f client.yaml
oc wait pod --for=condition=Ready -l app=fio-client --timeout=1h > /dev/null

oc cp ${job_info} ${namespace}/fio-client:/tmp
oc cp ${pfile} ${namespace}/fio-client:/tmp
oc cp ${server_ip} ${namespace}/fio-client:/tmp 

num_of_job_file=$(($num_of_wl * $num_of_bs))
for iter in $(seq 1 $num_of_job_file)
do
	oc cp job${iter}.fio ${namespace}/fio-client:/tmp
done

#---------------
# End of script
#---------------
