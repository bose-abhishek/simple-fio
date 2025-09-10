#==========================================================
# Creating and setting up the namespace
# ---------------------------------------------------------
namespace="simple-fio"
if [ `oc get project | grep ${namespace} | awk '{print $1}'` ]
then
        oc project ${namespace} > /dev/null 2>&1
else
        echo "Creating project ${namespace}"
        oc create namespace ${namespace}
        oc project ${namespace} > /dev/null 2>&1

fi
unit=`grep "^unit" config.file | awk -F "=" '{print $2}'`
if [ $unit == "vm" ]; then
	echo "Checking for python packages"
        pip install -r requirements.txt > /dev/null 2>&1
fi


#============================
# Check fio storage pod is up
#----------------------------
if [[ $(oc get pvc | grep fio-data-pvc | awk '{print $1}') != "fio-data-pvc" ]];
then
	storage_class=$(grep "^storageclass" config.file | awk -F "=" '{print $2}')
        export storage_class=${storage_class}
        envsubst < fio-data-pvc.yaml | oc create -f -
        #oc create -f fio-data-pvc.yaml
fi
if [[ $(oc get pods | grep fio-storage | awk '{print $1}') != "fio-storage" ]];
        then
        oc apply -f fio-storage.yaml
fi

