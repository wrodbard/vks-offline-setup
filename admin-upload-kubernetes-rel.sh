#!/bin/bash
set -o pipefail
source ./config/env.config

if ! command -v jq >/dev/null 2>&1 ; then
  echo "JQ not installed. Exiting...."
  exit 1
fi

if ! command -v wget >/dev/null 2>&1 ; then
  echo "wget not installed. Exiting...."
  exit 1
fi

if ! command -v govc >/dev/null 2>&1 ; then
  echo "govc not installed. Exiting...."
  exit 1
fi

source ./config/env.config

export GOVC_URL=$VCENTER_HOSTNAME
export GOVC_USERNAME=$VCENTER_USERNAME
export GOVC_PASSWORD=$VCENTER_PASSWORD
export GOVC_INSECURE=true
export GOVC_DATASTORE=$CL_DATASTORE
export GOVC_CLUSTER=$K8S_SUP_CLUSTER
export GOVC_RESOURCE_POOL=

############################ WIP

# upload to content library VKS

govc library.ls

govc library.create $CL_VKS

for files in $(ls $DOWNLOAD_VKR_OVA/*.tar.gz); do
    echo
    echo "Extracting the OVA files from the tarball: $files"
    tar -xzvf $files
    echo
    echo "Uploading the OVA files to the Content Library: $CL_VKS"
    for ovffile in $(ls ${files%.tar.gz}/*.*); do
        echo "Uploading the OVF file: $ovffile"
        govc library.import -n ${ovffile%.ovf} -m=true $CL_VKSs $ovffile
    done
    echo
    echo "Cleaning up..."
    [ -d "${files%.tar.gz}" ] && rm -rf "${files%.tar.gz}"
done

# upload to content library DLVM

govc library.ls

govc library.create $CL_DLVM

for files in $(ls $DOWNLOAD_DLVM_OVA/*.tar.gz); do
    echo
    echo "Extracting the OVA files from the tarball: $files"
    tar -xzvf $files
    echo
    echo "Uploading the OVA files to the Content Library: $CL_DLVM"
    for ovffile in $(ls ${files%.tar.gz}/*.*); do
        echo "Uploading the OVF file: $ovffile"
        govc library.import -n ${ovffile%.ovf} -m=true $CL_DLVM $ovffile
    done
    echo
    echo "Cleaning up..."
    [ -d "${files%.tar.gz}" ] && rm -rf "${files%.tar.gz}"
done

#echo "     tar -xzvf ${tkgrimage}.tar.gz"
#echo "     cd ${tkgrimage}"
#echo "     govc library.import -n ${tkgrimage} -m=true Local photon-ova.ovf"
#echo "     or"
#echo "     govc library.import -n ${tkgrimage} -m=true Local ubuntu-ova.ovf"