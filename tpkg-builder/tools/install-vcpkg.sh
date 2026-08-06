#!/bin/sh
# Copyright (c) 2026 [Ribose Inc](https://www.ribose.com).
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

# install-vcpkg.sh — vcpkg at the pinned baseline, at the canonical
# absolute path /opt/vcpkg. The image layer IS the cache (TODO.v2-1/13):
# vcpkg trees embed absolute paths, so the tree is produced at the same
# path every consumer reads it from — no restore script, no
# manifest-hash-sensitive tarball, no canonical-root map.
set -eu

# shellcheck disable=SC1091
. /opt/tpkg-builder/tools/lib.sh
load_pins
check_contract

git clone --quiet https://github.com/microsoft/vcpkg /opt/vcpkg
git -C /opt/vcpkg checkout --quiet "$VCPKG_COMMIT"

# On musl, VCPKG_FORCE_SYSTEM_BINARIES=1 is baked into the image env
# (vcpkg's downloaded cmake/ninja are glibc-linked — exit 127 on musl;
# tebako-rs ci/musl-build.sh). The vcpkg TOOL binary itself is a static
# musl executable upstream, so bootstrap works on both families.
/opt/vcpkg/bootstrap-vcpkg.sh -disableMetrics

# The shared binary-archive cache: the default (~/.cache/vcpkg) is
# root-private, which would strand `--user` local-dev runs. A world-
# writable files cache at a canonical path serves every uid.
mkdir -p /opt/vcpkg-cache
chmod 777 /opt/vcpkg-cache

# Consumer vcpkg invocations take a filesystem lock inside the root; keep
# the tree group/other-writable so non-root builds can take it.
chmod -R a+w /opt/vcpkg
