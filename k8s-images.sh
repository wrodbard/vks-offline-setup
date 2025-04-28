#!/bin/bash
set -o pipefail
source ./config/env.config
mapfile -t container_images < <(jq -r '.containers[]' './config/images.json')
mapfile -t helm_charts < <(jq -r '.helm[]' './config/images.json')

docker login ${PLATFORM_REGISTRY} -u "$PLATFORM_REGISTRY_USERNAME" -p "$PLATFORM_REGISTRY_PASSWORD"

for image in "${container_images[@]}"; do
    echo "==> Start to push container image: $image"
    version=$(echo "$image" | sed "s/^[^/]*\//$PLATFORM_REGISTRY\/ag-images\//")
    docker pull $image
    docker tag $image $version
    docker push $version
done

# helm gpu-operator chart
for image in "${helm_charts[@]}"; do
    filename=""
    echo "==> Pulling helm charts... $image"
    helm fetch "$image" --destination "./resources" # --username='$oauthtoken' --password="$NGC_API_KEY"

    if [ $? -ne 0 ]; then
        pulling_error_message="$pulling_error_message\nFailed to download helm chart: $image"
    fi
    filename=$(basename "$image")
    target=oci://"$PLATFORM_REGISTRY"/ag-images
    echo "==> Pushing helm chart $filename to $target"
	helm push "./resources/$filename" "$target" --insecure-skip-tls-verify --username "$PLATFORM_REGISTRY_USERNAME" --password "$PLATFORM_REGISTRY_PASSWORD"
done