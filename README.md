# simple-fio
As the name suggests, this is a simplified implementation of fio to be executed in a Kubernetes/Openshift environment without any bells and whistles of Elastic search, Grafana or any framework integration. 

This can be used to quickly run some fio tests in a Kubernetes/Openshift environment without any extra configuration. 

## How to run
1. git clone https://github.com/bose-abhishek/simple-fio.git
2. cd simple-fio/
3. Edit config file and set the appropriate parameters required.
4. sh simple_fio.sh
5. Once the test is over, execute the delete script (sh delete_simple_fio.sh)

## Check output

### All clients average results 
```
$ oc logs fio-client -f 
*********Fio_Job**************
All clients: (groupid=0, jobs=3): err= 0: pid=0: Tue Jul 12 18:52:21 2022
  read: IOPS=29.5k, BW=7375Mi (7733M)(432GiB/60001msec)
    slat (usec): min=3, max=557, avg=13.29, stdev= 5.48
    clat (usec): min=67, max=8068, avg=394.05, stdev=151.38
*********Fio_Job**************
All clients: (groupid=0, jobs=3): err= 0: pid=0: Tue Jul 12 18:54:22 2022
  read: IOPS=29.2k, BW=7305Mi (7660M)(428GiB/60001msec)
    slat (usec): min=3, max=1151, avg=13.22, stdev= 5.50
    clat (usec): min=68, max=39949, avg=396.89, stdev=182.15
*********Fio_Job**************
All clients: (groupid=0, jobs=3): err= 0: pid=0: Tue Jul 12 18:56:24 2022
  read: IOPS=28.1k, BW=7021Mi (7362M)(411GiB/60001msec)
    slat (usec): min=3, max=254, avg=13.57, stdev= 5.43
    clat (usec): min=66, max=15071, avg=410.07, stdev=171.74
```

### Detailed fio output
For detailed fio output or to check fio output of previous fio run, one can view the fio output directory stored in the pvc `fio-data-pvc`
```
# oc rsh fio-storage
sh-4.2# cd /mnt
sh-4.2# ls
fio_23_10_29_18_58.tar
```
