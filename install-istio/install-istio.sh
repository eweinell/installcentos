#!/bin/bash

# system cfg
if [ ! -e /etc/sysctl.d/99-elasticsearch.conf ]; then
	sysctl vm.max_map_count=262144
	echo 'vm.max_map_count=262144' > /etc/sysctl.d/99-elasticsearch.conf
fi

# enable operator hooks
cd /etc/origin/master/
if [ ! -e master-config.yaml.prepatch ]; then
	cp -p master-config.yaml master-config.yaml.prepatch
	oc ex config patch master-config.yaml.prepatch -p 'admissionConfig:
  pluginConfig:
    MutatingAdmissionWebhook:
      configuration:
        apiVersion: apiserver.config.k8s.io/v1alpha1
        kubeConfigFile: /dev/null
        kind: WebhookAdmission
    ValidatingAdmissionWebhook:
      configuration:
        apiVersion: apiserver.config.k8s.io/v1alpha1
        kubeConfigFile: /dev/null
        kind: WebhookAdmission' > master-config-patched.yaml || exit 1
    cp master-config-patched.yaml  master-config.yaml
	master-restart api
	master-restart controllers
	sleep 15
fi

# add operator project & install
oc new-project istio-operator
#curl https://raw.githubusercontent.com/Maistra/openshift-ansible/maistra-0.5/istio/istio_product_operator_template.yaml |oc process -f- --param=OPENSHIFT_ISTIO_MASTER_PUBLIC_URL=https://console.192.168.178.130.nip.io:8443 --param=OPENSHIFT_ISTIO_PREFIX=registry.access.redhat.com/openshift-istio-tech-preview/ --param=OPENSHIFT_RELEASE=v3.11.0 | oc create -f- -n istio-operator
curl https://raw.githubusercontent.com/Maistra/openshift-ansible/maistra-0.6/istio/istio_product_operator_template.yaml |oc process -f- --param=OPENSHIFT_ISTIO_MASTER_PUBLIC_URL=https://console.192.168.178.130.nip.io:8443 --param=OPENSHIFT_ISTIO_PREFIX=registry.access.redhat.com/openshift-istio-tech-preview/ --param=OPENSHIFT_RELEASE=v3.11.0 | oc create -f- -n istio-operator
# wait for operator
oc create -f ./istio-crd-full.yaml
# wait for install to complete


# add demo project
oc new-project myproject
oc adm policy add-scc-to-user anyuid -z default 
oc adm policy add-scc-to-user privileged -z default 

# install
oc apply -n myproject -f https://raw.githubusercontent.com/Maistra/bookinfo/master/bookinfo.yaml

# create istio config
oc apply -n myproject -f ./sample-config.yaml