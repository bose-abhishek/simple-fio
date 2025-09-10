# pip install kubernetes PyYAML Jinja2
import jinja2
import yaml
import json
import sys
from kubernetes import client, config
from kubernetes.client import V1Service, V1ServiceSpec, V1ServicePort, V1ObjectMeta, V1LabelSelector
from kubernetes.client import Configuration

# cp /root/mno/kubeconfig ~/.kube/
config.load_kube_config()

num = int(sys.argv[1])
#num = "%03d" % numVM
for vm in range(num):
    
    vm = "%03d" % vm
    data = {
        "vm_name": "fedora"+str(vm),
        "dv_name": "dv-fedora"+str(vm)
    }
    namespace = "simple-fio"

    jinja_env = jinja2.Environment(loader=jinja2.BaseLoader())

    with open('vm-svc.yaml.j2', 'r') as template_file:
        template_svc = template_file.read()
        template_svc1 = jinja2.Template(template_svc)
        rendered_template_svc = template_svc1.render(data)
        svc_data = yaml.safe_load(rendered_template_svc)
        #print(rendered_template_svc)
        v1 = client.CoreV1Api()
        v1.create_namespaced_service(body=svc_data,namespace=namespace)



# for vmi in $(oc get vmi -oname -n simple-fio); do oc -n simple-fio delete $vmi; done
# for vm in $(oc get vm -oname -n simple-fio); do oc -n simple-fio delete $vm; done
# oc get dv,pvc,pod,vm,vmi -n simple-fio
