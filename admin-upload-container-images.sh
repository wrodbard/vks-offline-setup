#!/bin/bash
set -o pipefail
source ./config/env.config

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <bootstrap|platform>"
	exit 1
fi

if ! command -v curl >/dev/null 2>&1 ; then
	echo "curl missing. Please install curl first."
	exit 1
fi

if ! command -v tanzu >/dev/null 2>&1 ; then
	echo "Tanzu CLI missing. Please install Tanzu CLI first."
  	exit 1
else
    if ! tanzu imgpkg --help > /dev/null 2>&1 ; then 
		mkdir -p ~/.local/share/tanzu-cli/
		tar -xzvf "$DOWNLOAD_DIR_BIN"/tanzu-cli-plugins.tar.gz -C  ~/.local/share/tanzu-cli/
#    	echo tanzu imgpkg plugin not installed. Please install the vmware-vsphere-plugin on this system
#        exit 1
    fi
fi

if ! command -v yq >/dev/null 2>&1 ; then
	echo "yq missing. Please install yq CLI first."
	exit 1
fi

# The main code
if [ "$1" == "bootstrap" ]; then
	echo "Bootstrap Supervisor Services"
	REGISTRY_URL=${BOOTSTRAP_REGISTRY}/${BOOTSTRAP_SUPSVC_REPO}
	REGISTRY_URL1=${BOOTSTRAP_REGISTRY}/${BOOTSTRAP_TNZPKG_REPO}
	REGISTRY_USERNAME=${BOOTSTRAP_REGISTRY_USERNAME}
	REGISTRY_PASSWORD=${BOOTSTRAP_REGISTRY_PASSWORD}
elif [ "$1" == "platform" ]; then
	echo "Platform Supervisor Services"
	REGISTRY_URL=${PLATFORM_REGISTRY}/${PLATFROM_SUPSVC_REPO}
	REGISTRY_URL1=${PLATFORM_REGISTRY}/${PLATFROM_TNZSVC_REPO}
	REGISTRY_USERNAME=${PLATFORM_REGISTRY_USERNAME}
	REGISTRY_PASSWORD=${PLATFORM_REGISTRY_PASSWORD}
	tanzu imgpkg copy --tar "$DOWNLOAD_DIR_BIN"/tanzu-packages.tar --to-repo "${REGISTRY_URL1}" --cosign-signatures --registry-username "${REGISTRY_USERNAME}" --registry-password "${REGISTRY_PASSWORD}"
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

for file in "${DOWNLOAD_DIR_YML}"/supsvc-*.yaml; do
	full_filename=$(basename "$file")
	file_name="${full_filename%.yaml}"
    	image=$(yq -P '(.|select(.kind == "Package").spec.template.spec.fetch[].imgpkgBundle.image)' "$file")
    	if [ "$image" ]
    	then
		if [[ "$image" == *"${REGISTRY_URL}"* ]]; then
			echo Now uploading "${DOWNLOAD_DIR_TAR}"/"$file_name".tar ...
			tanzu imgpkg copy --tar "${DOWNLOAD_DIR_TAR}"/"$file_name".tar --to-repo "${REGISTRY_URL}" --cosign-signatures --registry-username "${REGISTRY_USERNAME}" --registry-password "${REGISTRY_PASSWORD}"

			echo "Processing file - ${file} ..."
			export FILE_CONTENT=$(base64 "${file}" -w0)
			#	echo "$FILE_CONTENT"

			envsubst < ./config/carvel-spec.json > temp_final.json
			echo "Adding Supervisor Service to ${VCENTER_HOSTNAME}  ..."
			curl -ks -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "@temp_final.json" https://"${VCENTER_HOSTNAME}"/api/vcenter/namespace-management/supervisor-services
		fi
	fi
done

rm -f temp_final.json