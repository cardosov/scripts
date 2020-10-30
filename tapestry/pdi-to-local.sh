ls#!/usr/bin/env bash

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
  -h   | --help         	: displays this usage guide

EOF
  exit 1
}

DOG_FOOD_ENV=http://localhost:3000

#Metadata
CREDENTIALS="admin:password"
ZIP_FILE="all-types.zip"
ENTRY_POINT="all_types.ktr"
PROVIDER_ID=pdi-ktr
PROVIDER_ID_FOUNDRY=pdi-wn
METADATA_URL=http://172.20.42.207:8080/pentaho/osgi/cxf/dataflow-manager/generator/zip

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

FULL_URL=$DOG_FOOD_ENV/cxf/dataflow-manager/dataflows
  # --cookie 'request_uri=L2N4Zi9kYXRhZmxvdy1tYW5hZ2VyL2RhdGFmbG93cw%3D%3D; OAuth_Token_Request_State=b5ae3fc5-7536-417a-856d-c5fa07f7832f' \
echo "=> Submit the dataflow to dataflow-manager @ $FULL_URL"
curl -X POST \
  -H 'content-type: application/json' \
  -d "${JSON}" \
  $FULL_URL

echo "Success?..."
