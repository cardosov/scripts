#!/usr/bin/env bash

set -eo pipefail

PROGNAME=$0

usage() {
 cat <<EOF
  Usage: $PROGNAME [-c | --credentials ]=admin:pwd [-z | --zip-file ]=/some/where/file.zip ...

  -c   | --credentials  	: sets the credentials
  -z   | --zip-file     	: sets the zip file location
  -e   | --entry-point  	: sets the entry point inside the zip
  -p   | --provider-id  	: sets the provider
  -w   | --provider-id-wn	: sets the provider id for the workernodes in foundry
  -m   | --metadata-url		: sets the URL for the metadata generator endpoint
  -f   | --foundry-url		: sets the URL for the foundry env
  -s   | --sso-client      	: sets the SSO client from Keycloak
  -ss  | --sso-secret      	: sets the SSO client secret from Keycloak
  -h   | --help         	: displays this usage guide

EOF
  exit 1
}

DOG_FOOD_ENV=http://ldl-dev-millennium-7b.dogfood.trylumada.com

#Metadata
CREDENTIALS="admin:password"
ZIP_FILE="all-types.zip"
ENTRY_POINT="all_types.ktr"
PROVIDER_ID=pdi-ktr
PROVIDER_ID_FOUNDRY=pdi-wn
METADATA_URL=http://172.20.42.207:8080/pentaho/osgi/cxf/dataflow-manager/generator/zip

# Keycloak stuff 1
SSO_CLIENT="lumada-data-flow-studio-15690-sso-client"
SSO_CLIENT_SECRET="07396fa4-fef1-468d-af41-906727527efe"

# get values from named args
for key in "$@" 
do 
  case $key in 
		-c=*|--credentials=*) 
		CREDENTIALS="${key#*=}" && shift 
		;; 
		-z=*|--zip-file=*)
        ZIP_FILE="${key#*=}" && shift
		;;
		-e=*|--entry-point=*)
		ENTRY_POINT="${key#*=}" && shift 
		;;
		-p=*|--provider-id=*)
		PROVIDER_ID="${key#*=}" && shift
		;;
		-w=*|--provider-id-wn=*)
		PROVIDER_ID_FOUNDRY="${key#*=}" && shift
		;;
		-m=*|--metadata-url=*)
		METADATA_URL="${key#*=}" && shift
		;; 
		-f=*|--foundry-url=*)
		DOG_FOOD_ENV="${key#*=}" && shift
		;; 
		-s=*|--sso-client=*)
		SSO_CLIENT="${key#*=}" && shift
		;; 
		-ss=*|--sso-client-secret=*)
		SSO_CLIENT_SECRET="${key#*=}" && shift
		;; 
		-h|--help) usage
		;; 
	esac 
done

FIRST_TIME=false

# IP_ADDRESS=$( kubectl get services | grep lumada-data-integration | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" )

if $FIRST_TIME ; then

	kubectl apply -f resources/nginx-ingress-controller.yaml

	kubectl apply -f resources/keycloack-ingress.yaml

	# kubectl edit deployments -n nginx-ingress nginx-ingress-controller
	# Then in spec->template->spec->containers->args add - --enable-ssl-passthrough	

	#kubectl get secrets | grep "lumada-data-flow-studio-*"

	#kubectl get secrets | grep "lumada-data-flow-studio-.*-sso-gatekeeper*" | grep -oE '[0-9]+'
fi