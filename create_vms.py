# pip install kubernetes PyYAML Jinja2
import jinja2
import yaml
import json
import sys
from kubernetes import client, config

# cp /root/mno/kubeconfig ~/.kube/
config.load_kube_config()

num = int(sys.argv[1])
#num = "%03d" % numVM

def get_sc(file_path):
    with open(file_path, 'r') as file:
        for line in file:
            if line.startswith(f"storageclass="):
                return line.strip().split('=', 1)[1]
    return none

sc_name = get_sc("config.file")

for vm in range(num):
    
    vm = "%03d" % vm
    data = {
        "vm_name": "fedora"+str(vm),
        "dv_name": "dv-fedora"+str(vm),
        "sc_name": sc_name
    }

    with open('fedora.yaml.j2', 'r') as template_file:
    #with open('multiIO-fedora.yaml.j2', 'r') as template_file:
        template = template_file.read()

    jinja_env = jinja2.Environment(loader=jinja2.BaseLoader())
    rendered_template = jinja_env.from_string(template).render(data)
    vm_custom_resource = yaml.safe_load(rendered_template)
    api_extension = client.CustomObjectsApi()
    group = "kubevirt.io"
    version = "v1"
    namespace = "simple-fio"
    plural = "virtualmachines"
    api_extension.create_namespaced_custom_object(
        group=group,
        version=version,
        namespace=namespace,
        plural=plural,
        body=vm_custom_resource
    )



# for vmi in $(oc get vmi -oname -n simple-fio); do oc -n simple-fio delete $vmi; done
# for vm in $(oc get vm -oname -n simple-fio); do oc -n simple-fio delete $vm; done
# oc get dv,pvc,pod,vm,vmi -n simple-fio
