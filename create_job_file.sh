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

file=job.fio
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
	echo -e "[fio_test] \ntime_based=0 \nrw=write \nbs=256K \niodepth=1 \ncreate_on_open=1 \nfsync_on_close=1 \ngroup_reporting" >> ${pfile}
fi


echo -e "[fio_test]" >> ${file}
echo "rw=\${RW}" >> ${file}
echo "bs=\${BS}" >> ${file}
grep "^rwmixread" config.file >> ${file}
grep "^time_based" config.file >> ${file}
grep "^runtime" config.file >> ${file}
grep "^iodepth" config.file >> ${file}
grep "^rate_iops" config.file >> ${file}

#job=${workload}	
#job=`grep "^rw" config.file | head -n1 | awk -F "=" '{print $2}'`
		
# Additional FIO parameters based on job/workload
# For write workload, the parameters have been imported from Benchmark Operator
# For random workloads, the parameters have been imported from ODF QE CI job file
#--------------------------------------------------------------------------------
#if [ $job == "write" ]; then
#	echo "fsync_on_close=1" >> ${file}
#       	echo "create_on_open=1" >> ${file}
#elif [[ $job =~ ^[rand*] ]]; then
# 	echo "randrepeat=0" >> ${file}
#       	echo "allrandrepeat=0" >> ${file}
#fi
#-------------------------------------------------------------------------------
	
grep "^log_avg_msec" config.file >> ${file}
echo -e "write_iops_log=iops" >> ${file}
echo -e "write_lat_log=latency" >> ${file}
echo "group_reporting" >> ${file}
iter=$(($iter+1))
#

#--------------------------------------------------------

server=`grep "^server" config.file | awk -F "=" '{print $2}'`
sample=`grep "^sample" config.file | awk -F "=" '{print $2}'`
num_of_wl=${#wl_range[@]}
num_of_bs=${#bs_range[@]}
#export num_of_wl=${num_of_wl}
#export num_of_bs=${num_of_bs}

job_info=job_info.txt
> $job_info
echo "prefill=${prefill}" >> $job_info
echo "sample=${sample}" >> $job_info
echo "server=${server}" >> $job_info
echo "num_of_wl=${num_of_wl}" >> $job_info
echo "num_of_bs=${num_of_bs}" >> $job_info
echo "wl=\"${wl_range[@]}\"" >> $job_info
echo "bs=\"${bs_range[@]}\"" >> $job_info
