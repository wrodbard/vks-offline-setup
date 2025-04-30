#!/bin/bash
set -o pipefail
source ./config/env.config
mapfile -t container_images < <(jq -r '.containers[]' './config/images.json')
mapfile -t helm_charts < <(jq -r '.helm[]' './config/images.json')
mapfile -t llm < <(jq -c '.models.llm[]' './config/images.json')
mapfile -t embedding < <(jq -c '.models.embedding[]' './config/images.json')

docker login ${BOOTSTRAP_REGISTRY} -u "$BOOTSTRAP_REGISTRY_USERNAME" -p "$BOOTSTRAP_REGISTRY_PASSWORD"

for image in "${container_images[@]}"; do
    echo "==> Start to push container image: $image"
    version=$(echo "$image" | sed "s/^[^/]*\//$PLATFORM_REGISTRY\/$BOOTSTRAP_PROXY_CACHE\//")
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
    target=oci://"$BOOTSTRAP_REGISTRY"/charts
    echo "==> Pushing helm chart $filename to $target"
	helm push "./resources/$filename" "$target" --insecure-skip-tls-verify --username "$BOOTSTRAP_REGISTRY_USERNAME" --password "$BOOTSTRAP_REGISTRY_PASSWORD"
done

# LLM model profiles
llm_output=()
for m in "${llm[@]}"; do
    name=$(echo "$m" | jq -r '.name')
    uri=$(echo "$m" | jq -r '.uri')

    profiles=$(echo "$m" | jq -c '.profiles[]')
    for profile in $profiles; do
        profile_name=$(echo "$profile" | jq -r '.profile_name')
        profile_id=$(echo "$profile" | jq -r '.profile_id')
        llm_output+=("$name, $uri, $profile_name, $profile_id")
    done
done

# Pull all LLM model files
for item in "${llm_output[@]}"; do
    IFS=', ' read -r image_name uri profile_name profile_id <<< "$item"

    local local_model_cache_path="$LOCAL_RESOURCES_DIR/$image_name/$profile_name"_cache
    local local_model_store_path="$LOCAL_RESOURCES_DIR/$image_name/$profile_name"_model

    echo "==> Pulling model: $image_name profile: $profile_name to $local_model_cache_path"

    docker run -it --rm --name="$image_name" \
        -v "$local_model_cache_path":/opt/nim/.cache \
        -v "$local_model_store_path":/model-repo \
        -e NGC_API_KEY="$NGC_API_KEY" \
        $( [ -n "$HTTP_PROXY" ] && [ -n "$HTTPS_PROXY" ] && echo " -e http_proxy=$HTTP_PROXY -e https_proxy=$HTTPS_PROXY -e no_proxy=$NO_PROXY" ) \
        -u "$(id -u root)" \
        "$uri" \
        bash -c "create-model-store --profile $profile_id --model-store /model-repo"
    if [ $? -ne 0 ]; then
        pulling_error_message="$pulling_error_message\nFailed to download model profile: $profile_name"
    fi
done

# Pull all embedding model files
for item in "${emb_output[@]}"; do
    IFS=', ' read -r image_name uri profile_name profile_id <<< "$item"

    local local_model_cache_path="$LOCAL_RESOURCES_DIR/$image_name/$profile_name"_cache
    local local_model_store_path="$LOCAL_RESOURCES_DIR/$image_name/$profile_name"_model

    echo "==> Pulling model: $image_name profile: $profile_name to $local_model_cache_path"
    docker run -it --rm --name="$image_name" \
        -v "$local_model_cache_path":/opt/nim/.cache \
        -v "$local_model_store_path":/model-repo \
        -e NGC_API_KEY="$NGC_API_KEY" \
        $( [ -n "$HTTP_PROXY" ] && [ -n "$HTTPS_PROXY" ] && echo " -e http_proxy=$HTTP_PROXY -e https_proxy=$HTTPS_PROXY -e no_proxy=$NO_PROXY" ) \
        -u "$(id -u root)" \
        "$uri" \
        bash -c "download-to-cache --profile $profile_id"

    if [ $? -ne 0 ]; then
        pulling_error_message="$pulling_error_message\nFailed to download model profile: $profile_name"
    fi

    # tar all embedding model files
    path="$LOCAL_RESOURCES_DIR/$profile_name.tgz"
    tar -czvf $path -C $local_model_cache_path
    mkdir -p "$LOCAL_RESOURCES_DIR/$profile_name"
    mv $path "$LOCAL_RESOURCES_DIR/$profile_name"
    echo "Archived: $path"
done

## todo - add push llm and embed (need pais)