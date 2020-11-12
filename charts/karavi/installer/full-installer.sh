#!/bin/bash

# Copyright (c) 2020 Dell Inc., or its subsidiaries. All Rights Reserved.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#    http://www.apache.org/licenses/LICENSE-2.0


usage() {
   echo
   echo "$0"
   echo "Install all components of the Karavi ecosystem"
   echo
   echo "Arguments:"
   echo "-c             Directory where certificates are stored"
   echo
}

status() {
  echo
  echo "*"
  echo "* $@"
  echo
}

NAMESPACE="karavi"
CERT_MANAGER_VERSION="v1.0.4"
RESOURCE_DEFINITION_DIRECTORY="./resources"
CERTS_DIRECTORY="./certs"

check_dependencies() {
	# Check for helm

	# Check for kubernetes
}

install_linkerd() {
	# Add linkerd helm repo
	status "Installing linkerd"
	run_command "helm repo add linkerd https://helm.linkerd.io/stable"

	# Install linkerd via helm
	run_command "helm install linkerd \
		--set-file global.identityTrustAnchorsPEM=$CERTS_DIRECTORY/ca.crt \
		--set identity.issuer.scheme=kubernetes.io/tls \
		--set installNamespace=false \
		linkerd/linkerd2 \
		-n $NAMESPACE"
}

install_cert_manager() {
	# Add cert-manager helm repo
	status "Installing cert-manager"
	run_command "helm repo add jetstack https://charts.jetstack.io"

	# Install cert-manager via helm with custom resource definitions
	run_command "helm install cert-manager jetstack/cert-manager \
		--namespace $NAMESPACE \
		--version $CERT_MANAGER_VERSION \
		--set installCRDs=true"

	# Create kubernetes secret from certificates
	status "Installing certificates"
	run_command "kubectl create secret tls trust-anchor \
	--cert=$CERTS_DIRECTORY/ca.crt \
	--key=$CERTS_DIRECTORY/ca.key \
	--namespace=$NAMESPACE"

	# Create cert-manager CA issuer
	status "Creating cert-manager CA"
	run_command "cat <<EOF | kubectl apply -f -
	apiVersion: cert-manager.io/v1
	kind: Issuer
	metadata:
	  name: cert-manager-ca-issuer
	  namespace: $NAMESPACE
	spec:
	  ca:
	    secretName: trust-anchor
	EOF"

	# Create cert-manager certificate
	status "Configuring cert-manager CA"
	run_command "cat <<EOF | kubectl apply -f -
	apiVersion: cert-manager.io/v1
	kind: Certificate
	metadata:
	  name: cert-manager-certificate
	  namespace: $NAMESPACE
	spec:
	  secretName: cert-manager-certificate
	  duration: 24h
	  renewBefore: 1h
	  issuerRef:
	    name: cert-manager-ca-issuer
	    kind: Issuer
	  isCA: true
	  keyAlgorithm: ecdsa
	  usages:
	  - cert sign
	  - crl sign
	  - server auth
	  - client auth
	EOF"
}

install_otel_collector() {

}

install_grafana() {

}

install_prometheus() {

}

install_karavi() {

}

run_command() {
  CMDOUT=$(eval "${@}" 2>&1)
  local rc=$?

  if [ $rc -ne 0 ]; then
    echo
    echo "ERROR"
    echo "Received a non-zero return code ($rc) from the following comand:"
    echo "  ${@}"
    echo
    echo "Output was:"
    echo "${CMDOUT}"
    echo
    echo "Exiting"
    exit 1
  fi
}

while getopts "c:" opt; do
	case ${opt} in
		c )
			CERTS_DIRECTORY=$OPTARG
			;;
		\? )
			echo "Invalid option: -$OPTARG" >&2
			;;
		: )
			echo "Invalid option: $OPTARG requires an argument" >&2
			;;
	esac
done

check_dependencies
install_linkerd
install_cert_manager
install_otel_collector
install_prometheus
install_grafana
install_karavi
