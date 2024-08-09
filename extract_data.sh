#!/bin/bash

file=output.log
namespace=simple-fio
platform=`grep "^platform" config.file | awk -F "=" '{print $2}'`

extract_data () {
	oc -n ${namespace} logs -f fio-client > $file

	iter=1
	rw=`grep "^rw" config.file | head -n1 | awk -F "=" '{print $2}'`
	sample=`grep Sample $file | awk -F "Sample=" '{print $2}' | awk -F ";" '{print $1}' | sort -n | uniq | tail -n1`
	#echo $sample
	if [[ ${rw} == "randrw" ]]; then iter=2; fi
	for wld in $(seq 1 ${iter})
	do
		#sample=`grep "^sample" config.file | awk -F "=" '{print $2}'`
		grep  "Sample=1" $file | awk -F "Sample=1" '{print $1}' >> start_time
		grep  -A5 "Sample=${sample}" $file| grep "All clients"  | awk -F "pid=0:" '{print $2}' >> end_time

		if [[ $iter -eq 2 && $wld -eq 1 ]]; then
			echo `grep "Sample=1" $file | awk -F ";" '{print $4}' | awk -F "=" '{print $2}'`-read >> workload
		elif [[ $iter -eq 2 && $wld -eq 2 ]]; then
			echo `grep "Sample=1" $file | awk -F ";" '{print $4}' | awk -F "=" '{print $2}'`-write >> workload
		else
			printf "%10s\n" `grep "Sample=1" $file | awk -F ";" '{print $4}' | awk -F "=" '{print $2}'` >> workload
		fi
		grep "Sample=1" $file | awk -F ";" '{print $2}'  >> server
		printf "%6s\n" `grep "Sample=1" $file | awk -F ";" '{print $3}' | awk -F "=" '{print $2}'` >> bs
		grep "Sample=1" $file | awk -F ";" '{print $5, "|", $6}' >> job_detail
	done

	count=0;
	for i in `grep "iops" $file | awk -F "avg=" '{print $2}' | awk -F "," '{print $1}'`;
	do
        printf "%12s" "$i|";
        count=$(($count+1))
        if [[ $count%${sample} -eq 0 ]]; then
                echo ""
        fi
	done > iops
	sed -i ' s/.$//' iops

	count=0
	for i in `grep "clat" $file | awk -F "avg=" '{print $2}' | awk -F "," '{print $1}'`;
	do
        printf "%12s" "$i|";
        count=$(($count+1))
        if [[ $count%${sample} -eq 0 ]]; then
                echo ""
        fi
	done > clat

}

if [ $platform == "bm" ]; then
	extract_data
	echo "start_time|end_time|fio-Server|workload|bs|numjobs|iodepth"
	paste -d'|' start_time end_time server workload bs job_detail iops clat
	rm -f consumer start_time end_time server workload bs job_detail iops clat output.log
elif [ $platform == "hcp" ]; then
	echo "consumers|start_time|end_time|fio-Server|workload|bs|numjobs|iodepth"
	for consumer in $(cat consumers.lst)
	do
		oc config use $consumer > /dev/null
		extract_data
		count=0;
		for i in `grep "iops" $file | awk -F "avg=" '{print $2}' | awk -F "," '{print $1}'`;
		do
			count=$(($count+1))
        		if [[ $count%${sample} -eq 0 ]]; then
				oc get infrastructure cluster  -o jsonpath='{.status.etcdDiscoveryDomain}' >> consumer
				echo "" >> consumer
        		fi
		done
		paste -d'|' consumer start_time end_time server workload bs job_detail iops clat
		rm -f consumer start_time end_time server workload bs job_detail iops clat output.log
		echo "--------------"
	done
fi

