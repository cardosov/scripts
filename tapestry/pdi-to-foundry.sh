#!/usr/bin/env bash

set -eo pipefail

PROGNAME=$0

usage() {
 cat <<EOF
  Usage: $PROGNAME [-c | --credentials ]=admin:pwd [-z | --zip-file ]=/some/where/file.zip ...

  -c   | --credentials  	: sets the credentials for the metadata endpoint in "user:pwd" format
  -z   | --zip-file     	: sets the local zip file location
  -e   | --entry-point  	: sets the entry point inside the zip
  -p   | --provider-id  	: sets the provider. Defaults to 'pdi-ktr'
  -w   | --provider-id-wn	: sets the provider id for the workernodes in foundry. Defaults to 'pdi-wn'
  -m   | --metadata-url		: sets the URL for the metadata generator endpoint. Defaults to 'http://172.20.42.207:8080/pentaho/osgi/cxf/dataflow-manager/generator/zip'
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

echo "=> Get metadata related to the zip from $METADATA_URL"
JSON=$( curl -v \
	-u $CREDENTIALS \
	-F "source=@$ZIP_FILE;type=application/zip" \
	-F entryPoint=$ENTRY_POINT \
	-F providerId=$PROVIDER_ID \
	$METADATA_URL )

if [ -z "$JSON" ]; then
	echo "No response received from $METADATA_URL"
	exit 1
fi

JSON=$( echo ${JSON/$PROVIDER_ID/$PROVIDER_ID_FOUNDRY} ) # replace the providerId

# Keycloak stuff 2
KC_USER="foundry"
KC_PWD=$(kubectl get keycloakusers -n hitachi-solutions keycloak-user -o jsonpath={.spec.user.credentials[0].value})
KC_URL=$DOG_FOOD_ENV/hitachi-solutions/hscp-hitachi-solutions/keycloak/realms/default/protocol/openid-connect/token


echo "=> Get the token from $KC_URL $KC_PWD"
TOKEN_DATA=$(
	curl -X POST \
		-u "$SSO_CLIENT:$SSO_CLIENT_SECRET" \
	 	-d "grant_type=password&username=$KC_USER&password=$KC_PWD&scope=cn" \
	 	--insecure \
	 	$KC_URL )

if [ -z "$TOKEN_DATA" ]; then
	echo "No token received from $KC_URL"
	exit 2
fi

TOKEN=$( echo $TOKEN_DATA | jq -r .access_token ) # extract the token
TOKEN_TYPE=$( echo $TOKEN_DATA | jq -r .token_type ) # extract the token_type

  # --cookie 'request_uri=L2N4Zi9kYXRhZmxvdy1tYW5hZ2VyL2RhdGFmbG93cw%3D%3D; OAuth_Token_Request_State=b5ae3fc5-7536-417a-856d-c5fa07f7832f' \
echo "=> Submit the dataflow to dataflow-manager @ $DOG_FOOD_ENV/dataflow-manager/api/dataflows"
curl -X POST \
  -H "authorization: ${TOKEN_TYPE^} ${TOKEN}" \
  -H 'content-type: application/json' \
  -d "${JSON}" \
  --insecure \
  $DOG_FOOD_ENV/hitachi-solutions/lumada-data-flow-studio-1600447865889/lumada-data-flow-studio-16889-app/cxf/dataflow-manager/dataflows


echo "Success?..."