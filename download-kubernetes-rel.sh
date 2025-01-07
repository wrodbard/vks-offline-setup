#!/bin/bash

###################################################

# Define the directory to upload the files
DOWNLOAD_KR_OVA="./kubernetes-releases-ova"

if ! command -v jq >/dev/null 2>&1 ; then
  echo "JQ not installed. Exiting...."
  exit 1
fi
if ! command -v wget >/dev/null 2>&1 ; then
  echo "wget not installed. Exiting...."
  exit 1
fi

# Create the download directory if it doesn't exist
mkdir -p "$DOWNLOAD_KR_OVA"

echo
echo "The VMware subscribed content library has the following Kubernetes Release images ... "
echo
curl -s https://wp-content.vmware.com/v2/latest/items.json |jq -r '.items[]| .created + "\t" + .name'|sort
echo
echo "The list shown above is sorted by release date with the corrosponding names of the"
echo "Kubernetes Release in the second column."
read -p "Enter the name of the Kubernetes Release OVA that you want to download and zip for offline upload: " tkgrimage
echo
echo "Downloading all files for the TKG image: ${tkgrimage} ..."
echo
wget -q --show-progress --no-parent -r -nH --cut-dirs=2 --reject="index.html*" https://wp-content.vmware.com/v2/latest/"${tkgrimage}"/
echo "Compressing downloaded files..."
tar -cvzf "${tkgrimage}".tar.gz "${tkgrimage}"
echo
echo "Cleaning up..."
[ -d "${tkgrimage}" ] && rm -rf "${tkgrimage}"
mv "${tkgrimage}".tar.gz "${DOWNLOAD_KR_OVA}" 
echo "Copy the file ${tkgrimage}.tar.gz to the offline admin machine that has access to the vSphere environment."
echo "You can untar the file and upload the OVA files to a Content Library called Local..."
echo "Optionally, you can install and configure govc on the offline admin machine."
echo "Use the following command on the admin machine to import the image to the vCenter Content Library called "Local"..."
echo
echo "     tar -xzvf ${tkgrimage}.tar.gz"
echo "     cd ${tkgrimage}"
echo "     govc library.import -n ${tkgrimage} -m=true Local photon-ova.ovf"
echo "     or"
echo "     govc library.import -n ${tkgrimage} -m=true Local ubuntu-ova.ovf"