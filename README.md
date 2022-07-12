# simple-fio
As the name suggests, this is a simplified implementation of fio to be executed in a Kubernetes/Openshift environment without any bells and whistles of Elastic search, Grafana or any framework integration. 

## How to run
1. git clone https://github.com/bose-abhishek/simple-fio.git
2. cd simple-fio/
3. Edit config file and set the appropriate parameters required.
4. sh simple_fio.sh
5. Once the test is over, execute the delete script (sh delete_simple_fio.sh)

## Check output
$ oc logs fio-client -f

