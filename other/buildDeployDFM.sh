#!/usr/bin/env bash

set -eo pipefail

DFM_PROJECT_FOLDER=$1
BA_SERVER_LOCATION=$2

if [ -z "$DFM_PROJECT_FOLDER" ]; then 
	echo 'DFM_PROJECT_FOLDER not set'
	DFM_PROJECT_FOLDER="/home/vcardoso/forks/dataflow-manager/"
fi

if [ -z "$BA_SERVER_LOCATION" ]; then 
	echo 'BA_SERVER_LOCATION not set'
	BA_SERVER_LOCATION="/home/vcardoso/Pentaho/server"
fi

#echo $DFM_PROJECT_FOLDER
#echo $BA_SERVER_LOCATION/pentaho-server/pentaho-solutions/system/karaf/deploy/

cd $DFM_PROJECT_FOLDER

$BA_SERVER_LOCATION/pentaho-server/stop-pentaho.sh

mvn clean install -DskipTests -P pentaho && \
cp ./backend/assemblies/pentaho/karaf-feature/target/dataflow-manager.kar $BA_SERVER_LOCATION/pentaho-server/pentaho-solutions/system/karaf/deploy/ && \
cp ./webclient/assemblies/pentaho/war/target/dataflow-manager.war $BA_SERVER_LOCATION/pentaho-server/tomcat/webapps/

echo "Copied dataflow-manager.kar into $BA_SERVER_LOCATION/pentaho-server/pentaho-solutions/system/karaf/deploy"
echo "Copied dataflow-manager.war into $BA_SERVER_LOCATION/pentaho-server/tomcat/webapps"

rm -rf $BA_SERVER_LOCATION/pentaho-server/pentaho-solutions/system/karaf/caches

$BA_SERVER_LOCATION/pentaho-server/start-pentaho.sh
