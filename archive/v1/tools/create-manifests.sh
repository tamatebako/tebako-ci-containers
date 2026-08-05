#!/bin/bash
# Copyright (c) 2025 [Ribose Inc](https://www.ribose.com).
# All rights reserved.
# This file is a part of the Tebako project.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# Usage: ./create-manifests.sh <container> <base_tag>
# Example: ./create-manifests.sh ubuntu-20.04 1.2.3

container=$1
base_tag=$2

# Registries configuration
declare -A registries=(
    ["ghcr"]="ghcr.io/tamatebako"
    ["docker"]="tebako"
)

# Create and push manifest for each registry
for registry_key in "${!registries[@]}"; do
    registry="${registries[$registry_key]}"
    echo "Creating manifest for ${registry}/tebako-${container}:${base_tag}"

    # Create manifest
    docker manifest create \
        "${registry}/tebako-${container}:${base_tag}" \
        --amend "${registry}/tebako-${container}:${base_tag}-amd64" \
        --amend "${registry}/tebako-${container}:${base_tag}-arm64"

    # Push manifest
    docker manifest push "${registry}/tebako-${container}:${base_tag}"

    # Handle latest tag for SHA tags
    if [[ $base_tag == sha* ]]; then
        echo "Creating latest manifest for ${registry}/tebako-${container}"
        # Push SHA tag manifest again (seems to be required in original script)
        docker manifest push "${registry}/tebako-${container}:${base_tag}"

        # Create and push latest tag
        docker manifest create \
            "${registry}/tebako-${container}:latest" \
            --amend "${registry}/tebako-${container}:${base_tag}-amd64" \
            --amend "${registry}/tebako-${container}:${base_tag}-arm64"

        docker manifest push "${registry}/tebako-${container}:latest"
    fi
done
