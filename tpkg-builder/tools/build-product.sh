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

# build-product.sh — build the tebako product binaries at the pinned ref
# and install them to /usr/local/bin. This is the image's deepest proof:
# tfs-cli pulls dwarfs-t-sys (the vendored dwarfs-t C++ build against the
# baked vcpkg tree) AND tebako-signer (rnp-rs's vendored build — bindgen
# dlopening libclang, Botan's configure gating on gcc >= 11), so a green
# run here proves the whole toolchain contract a consumer leg relies on.
#
# The dwarfs-t ports land in /opt/vcpkg-installed/dwarfs (the baked
# DWARFS_RS_VCPKG_INSTALLED_DIR) as a side effect — the cache this image
# exists to ship.
#
# Mirrors tebako-rs ci/gnu-floor-build.sh and ci/musl-build.sh; the
# package set is the release set (release.yml).
set -eu

# shellcheck disable=SC1091
. /opt/tpkg-builder/tools/lib.sh
load_pins
check_contract

export PATH="/opt/cargo/bin:$PATH"
cd /opt/tebako-rs

PKGS="-p tebako-bootstrap -p tfs-cli -p tebako-pkg -p tebako-cli -p tebako-shim"
if [ "$TPKB_FAMILY" = "linux-musl" ]; then
  # Native WITHOUT --target: with an explicit --target cargo applies
  # RUSTFLAGS to target units ONLY, and rnp-rs's build script would link
  # crt-static and die in bindgen ("Dynamic loading not supported",
  # tebako-rs run 30745532174). The container's host triple IS the musl
  # target, so plain --release builds it and RUSTFLAGS
  # (-C target-feature=-crt-static, baked) covers host units too.
  # shellcheck disable=SC2086
  cargo build --release $PKGS
  BIN_DIR=target/release
else
  # shellcheck disable=SC2086
  cargo build --release --target "$RUST_TARGET" $PKGS
  BIN_DIR="target/$RUST_TARGET/release"
fi

for b in tebako-bootstrap tfs tebako-pkg tebako tebako-shim; do
  install -m 0755 "$BIN_DIR/$b" /usr/local/bin/
done

# The target dir is gigabytes of intermediate state no consumer reuses
# (the vcpkg installed trees — the actual cache — live outside it). Drop
# it; keep the cargo registry (that IS consumer-reused) and re-open its
# permissions after the root-owned build filled it.
rm -rf target
chmod -R a+w /opt/cargo

tfs help >/dev/null
tebako --version
