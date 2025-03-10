# simple-fio
The purpose of this software is to provide a simple mechanism to perform fio tests on Openshift Data Foundation (ODF) and other Kubernetes supported storageclass without the need for additional configurations.

The architecture of this tool has been designed such that the initial configuration and prefill is separate from testing.

In this version we support testing of pods on native ODF and also ODF on HCP clusters.

## How to run
1. git clone https://github.com/bose-abhishek/simple-fio.git
2. cd simple-fio/
3. Edit config file and set the appropriate parameters required. Described in detail in the next section.
4. Add consumers in the consumers.lst if using HCP.
5. Execute the setup prepare script `sh 01_prepare_setup.sh`
6. Once the prefill is complete, execute `sh 02_run_tests.sh`. To run additional tests, you may change the fio parameters in the config file and re-execute `sh 02_run_tests.sh`.

   **Note**: numjobs & size cannot be changed in this step. To change these parameters you may need to execute the delete script and re-run `sh 01_prepare_setup.sh`
7. Once the test is over, execute the delete script (`sh delete_simple_fio.sh`) to delete the test setup (fio server and client pods).
8. To delete the project, execute the nuke script. This will delete the namespace, fio storage along with all the stored data (`sh nuke_simple-fio.sh`). 

## Test Configuration
To execute a fio test, one needs to only change the parameters in the config.file.
There are three sections in the config.file:
1. OCS Parameters
   - platform: This option is to select on which platform the test will be executed. It can be either the native ODF (bm) or in the Hosted Control Plane.
     * options: bm | hcp
   - storage_type: This defines the undelying storage class to be used.
     * options: ocs-storagecluster-ceph-rbd | ocs-storagecluster-cephfs

2. FIO Execution Parameters
   - server: Number of fio server pods (usually this equals to the number of ODF workers or multiples of it). FIO test is actually executed on it, RBD volumes or CephFS mounts are present in these pods.
   - sample: Number of iterations of the test
   - prefill: To perform prefill or not for RBD volumes
     * options: true | false
   - storage(Gi): size of each PVC (should be larger than 'numjob x fio volume/file size')
  
3. FIO parameters: These parameters are used exactly as defined in the [FIO documentation](https://fio.readthedocs.io/en/latest/fio_doc.html)
   - [direct](https://fio.readthedocs.io/en/latest/fio_doc.html#cmdoption-arg-direct): If value is true, use non-buffered I/O. This is usually O_DIRECT.
   - [rw](https://fio.readthedocs.io/en/latest/fio_doc.html#cmdoption-arg-readwrite): Type of I/O pattern. Multiple workloads can be specified at a time. Workloads will run sequentially as mentioned in the config file.
     * rw=read | write | randread | randwrite | randrw
   - [bs](https://fio.readthedocs.io/en/latest/fio_doc.html#block-size): The block size in bytes used for I/O units. Unlike fio, here multiple block sizes can be mentioned with space separated.
     * bs=8k 16k
   - [numjobs](https://fio.readthedocs.io/en/latest/fio_doc.html#cmdoption-arg-numjobs): Create the specified number of clones of this job. Each clone of job is spawned as an independent thread or process.
   - [time_based](https://fio.readthedocs.io/en/latest/fio_doc.html#cmdoption-arg-time-based): If set, fio will run for the duration of the runtime specified even if the file(s) are completely read or written. 
     * time_based=0 | 1
   - [runtime](https://fio.readthedocs.io/en/latest/fio_doc.html#cmdoption-arg-runtime): Limit runtime. The test will run until it completes the configured I/O workload or until it has run for this specified amount of time, whichever occurs first. The value is interpreted in seconds.
   - [size](https://fio.readthedocs.io/en/latest/fio_doc.html#cmdoption-arg-size): File or block size.
   - [iodepth](https://fio.readthedocs.io/en/latest/fio_doc.html#cmdoption-arg-iodepth): Number of I/O units to keep in flight against the file
   - [log_avg_msec](https://fio.readthedocs.io/en/latest/fio_doc.html#cmdoption-arg-log-avg-msec): Setting this option makes fio average the each log entry over the specified period of time, reducing the resolution of the log. This defines the granularity of the fio logs and can be changed according to test requirements. As a rule of thumb, it can be set as:
      * log_avg_msec=5000 # 5 seconds for 5/10 minute jobs
      * log_avg_msec=1000 # 10 seconds for more than 10 minute jobs

* Apart from the above mentioned fio parameters, few of the parameters are automatically set in the fio job file depending on the workload type.
    * When `rw` is set as `write`, `fsync_on_close=1` and `create_on_open=1` is applied.
    * When `rw` is set as any random workload, `randrepeat=0` and `allrandrepeat=0` is applied.

## How to check results

### All clients average results 
```
$ oc logs fio-client -f
Initializing and Configuring FIO jobs
*********Prefill**************
All clients: (groupid=0, jobs=3): err= 0: pid=0: Tue Nov 21 11:13:16 2023
  write: IOPS=968, BW=121Mi (127M)(60.0GiB/507636msec); 0 zone resets
    slat (usec): min=3, max=3010, avg=79.17, stdev=89.26
    clat (usec): min=3059, max=64052, avg=12252.21, stdev=2690.49
     lat (usec): min=3193, max=64210, avg=12331.38, stdev=2689.03
   bw (  KiB/s): min=71680, max=254976, per=99.98%, avg=124514.84, stdev=797.60, samples=12112
   iops        : min=  560, max= 1992, avg=972.70, stdev= 6.23, samples=12112
```
### Detailed fio output
For detailed fio output or to check fio output of previous fio run, one can view the fio output directory stored in the pvc `fio-data-pvc`
```
# oc rsh fio-storage

sh-4.2# ls -l /mnt
total 328
-rw-r--r--. 1 1000710000 1000710000 81920 Nov 21 11:23 fio_16k_randread_sample1_23_11_21_11_23.tar
-rw-r--r--. 1 1000710000 1000710000 81920 Nov 21 11:26 fio_16k_randread_sample2_23_11_21_11_26.tar
-rw-r--r--. 1 1000710000 1000710000 81920 Nov 21 11:17 fio_8k_randread_sample1_23_11_21_11_17.tar
-rw-r--r--. 1 1000710000 1000710000 81920 Nov 21 11:20 fio_8k_randread_sample2_23_11_21_11_20.tar
-rw-r--r--. 1 1000710000 1000710000  7862 Nov 21 11:13 prefill_output.log
```


