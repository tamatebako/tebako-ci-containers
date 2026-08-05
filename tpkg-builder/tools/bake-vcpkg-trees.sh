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

# bake-vcpkg-trees.sh — the two vcpkg installed trees, baked as image
# layers at their canonical absolute paths:
#
#   /opt/vcpkg-installed/dwarfs/<triplet>   the dwarfs-t dependency closure
#                                           (boost, openssl, flatbuffers,
#                                           fmt, ...; filled by the product
#                                           build's manifest-mode install —
#                                           build-product.sh runs next)
#   /opt/vcpkg-installed/sqfs/<triplet>     squashfs-tools-ng (sqfs-sys's
#                                           serialized pre-install —
#                                           its build.rs short-circuits on
#                                           SQFS_SYS_VCPKG_INSTALLED_DIR)
#
# Also clones the pinned source checkouts (/opt/dwarfs-rs, /opt/tebako-rs)
# and gates the vcpkg baseline pin against dwarfs-t's vcpkg.json (the
# single owner) — a drifted pin fails the bake here, not a consumer leg.
set -eu

# shellcheck disable=SC1091
. /opt/tpkg-builder/tools/lib.sh
load_pins
check_contract

echo "== clone dwarfs-rs ($DWARFS_RS_REF) =="
git clone --quiet --recursive https://github.com/tamatebako/dwarfs-rs /opt/dwarfs-rs
git -C /opt/dwarfs-rs checkout --quiet "$DWARFS_RS_REF"
git -C /opt/dwarfs-rs submodule update --init --recursive

echo "== clone tebako ($TEBAKO_REF) =="
git clone --quiet https://github.com/tamatebako/tebako /opt/tebako-rs
git -C /opt/tebako-rs checkout --quiet "$TEBAKO_REF"

echo "== vcpkg baseline parity gate =="
# The owner of the baseline is dwarfs-t/vcpkg.json (builtin-baseline);
# pins.env mirrors it and this assert is the parity check the SSOT law
# allows in place of a flow (separate release chains).
baseline=$(grep -o '"builtin-baseline":[^"]*"[^"]*"' /opt/dwarfs-rs/dwarfs-t/vcpkg.json | cut -d'"' -f4)
echo "dwarfs-t builtin-baseline: $baseline"
[ "$baseline" = "$VCPKG_COMMIT" ] || {
  echo "::error::VCPKG_COMMIT ($VCPKG_COMMIT) != dwarfs-t builtin-baseline ($baseline) — bump pins.env" >&2
  exit 65
}

# musl only: the overlay triplets, generated EXACTLY as tebako-rs
# ci/musl-build.sh does — the triplet content feeds vcpkg's ABI hash, so a
# drifted generator would silently rebuild every port in consumer legs.
# (arm64-linux-musl is not checked into dwarfs-t yet; upstreaming is a
# documented follow-up in musl-build.sh.)
if [ "$TPKB_FAMILY" = "linux-musl" ]; then
  DWARFS_TRIPLETS=/opt/dwarfs-rs/dwarfs-t/vcpkg_triplets
  SQFS_TRIPLETS=/opt/tebako-rs/crates/sqfs-sys/vcpkg_triplets
  mk_triplet() {  # $1 = new name, $2 = arch (x64|arm64), $3 = linkage (static|dynamic)
    # CRT linkage must follow library linkage: with VCPKG_CRT_LINKAGE
    # static, vcpkg's Linux toolchain appends -static to
    # CMAKE_*_LINKER_FLAGS, which breaks shared-library links (the
    # botan:x64-linux-musl-dynamic lesson, tebako-rs run 30217620407).
    crt=static; [ "$3" = dynamic ] && crt=dynamic
    sed -e "s/VCPKG_TARGET_ARCHITECTURE x64/VCPKG_TARGET_ARCHITECTURE $2/" \
        -e "s/VCPKG_LIBRARY_LINKAGE static/VCPKG_LIBRARY_LINKAGE $3/" \
        -e "s/VCPKG_CRT_LINKAGE static/VCPKG_CRT_LINKAGE $crt/" \
        "$DWARFS_TRIPLETS/x64-linux-musl.cmake" > "$DWARFS_TRIPLETS/$1.cmake"
  }
  [ -f "$DWARFS_TRIPLETS/$VCPKG_TRIPLET.cmake" ] || {
    case "$VCPKG_TRIPLET" in
      arm64-linux-musl) mk_triplet "$VCPKG_TRIPLET" arm64 static ;;
    esac
  }
  if [ ! -f "$SQFS_TRIPLETS/$VCPKG_TRIPLET.cmake" ]; then
    sed -e "s/VCPKG_TARGET_ARCHITECTURE x64/VCPKG_TARGET_ARCHITECTURE $( [ "$VCPKG_TRIPLET" = "arm64-linux-musl" ] && echo arm64 || echo x64 )/" \
        "$DWARFS_TRIPLETS/x64-linux-musl.cmake" > "$SQFS_TRIPLETS/$VCPKG_TRIPLET.cmake"
  fi
fi

echo "== pre-install squashfs-tools-ng ($VCPKG_TRIPLET) =="
# Serialized on purpose: sqfs-sys's build.rs would otherwise race
# dwarfs-t-sys's CMake-driven vcpkg run on the vcpkg-root filesystem lock
# (the tebako-rs ci.yml note).
/opt/vcpkg/vcpkg install \
  --vcpkg-root /opt/vcpkg \
  --x-wait-for-lock \
  --x-manifest-root /opt/tebako-rs/crates/sqfs-sys \
  --x-install-root /opt/vcpkg-installed/sqfs \
  --triplet "$VCPKG_TRIPLET" \
  --overlay-triplets /opt/tebako-rs/crates/sqfs-sys/vcpkg_triplets \
  --overlay-ports /opt/tebako-rs/crates/sqfs-sys/vcpkg_ports

test -d "/opt/vcpkg-installed/sqfs/$VCPKG_TRIPLET/include/sqfs" || {
  echo "::error::the sqfs tree did not land where SQFS_SYS_VCPKG_INSTALLED_DIR points" >&2
  exit 65
}

# The installed trees are the ABI-anchored contract: readable by every
# uid, writable by no consumer (a mutation would poison the tree's ABI
# bookkeeping for later legs of the same container instance).
chmod -R a+rX /opt/vcpkg-installed /opt/dwarfs-rs /opt/tebako-rs
