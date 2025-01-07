#!/bin/bash

###################################################
## Modify the three variables below to match your environment
###################################################
VCENTER_HOSTNAME=192.168.100.50
VCENTER_USERNAME=administrator@vsphere.local
VCENTER_PASSWORD='VMware1!'


###################################################

# Define the directory to upload the files
DOWNLOAD_DIR_YML="./supervisor-services-yml"

if ! command -v curl >/dev/null 2>&1 ; then
  echo "curl missing. Please install curl first."
  exit 1
fi

HEADER_CONTENTTYPE="Content-Type: application/json"
################################################
# Login to VCenter and get Session ID
###############################################
SESSION_ID=$(curl -sk -X POST https://${VCENTER_HOSTNAME}/rest/com/vmware/cis/session --user ${VCENTER_USERNAME}:${VCENTER_PASSWORD} |jq -r '.value')
if [ -z "${SESSION_ID}" ]
then
	echo "Error: Could not connect to the VCenter. Please validate!!"
	exit 1
fi
echo Authenticated successfully to VC with Session ID - "${SESSION_ID}" ...
HEADER_SESSIONID="vmware-api-session-id: ${SESSION_ID}"

for filename in "$DOWNLOAD_DIR_YML"/supsvc-*.yaml; do

	echo "Processing file - ${filename} ..."
	export FILE_CONTENT=$(base64 "${filename}" -w0)
	echo "$FILE_CONTENT"

	envsubst < ./config/carvel-spec.json > temp_final.json
	echo "Adding Supervisor Service to ${VCENTER_HOSTNAME}  ..."
	curl -ks -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "@temp_final.json" https://${VCENTER_HOSTNAME}/api/vcenter/namespace-management/supervisor-services
done
rm -f temp_final.json