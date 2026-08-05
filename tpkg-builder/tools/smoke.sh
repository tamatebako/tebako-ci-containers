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

# smoke.sh — the tpkg-builder image proof.
#
#   smoke.sh          full: interface + contract asserts + the probe crate
#                     (a cold cargo build against the heaviest dependency,
#                     dwarfs-t-sys, reusing the baked vcpkg tree)
#   smoke.sh --light  interface + contract asserts only (the image-build
#                     RUN layer and the post-publish verify; the publish
#                     workflow's pre-push gate runs the full form)
set -eu

# shellcheck disable=SC1091
. /opt/tpkg-builder/tools/lib.sh
load_pins
check_contract

LIGHT=0
[ "${1:-}" = "--light" ] && LIGHT=1

echo "== toolchain =="
rustc --version
cargo --version
cmake --version | head -1
ninja --version
ruby --version
git --version
if [ "$TPKB_FAMILY" = "linux-gnu" ]; then
  patchelf --version
fi

echo "== pinned versions =="
[ "$(rustc --version | cut -d' ' -f2)" = "$RUST_VERSION" ] || {
  echo "::error::rustc != pin $RUST_VERSION" >&2; exit 65; }
baseline=$(grep -o '"builtin-baseline":[^"]*"[^"]*"' /opt/dwarfs-rs/dwarfs-t/vcpkg.json | cut -d'"' -f4)
[ "$baseline" = "$VCPKG_COMMIT" ] || {
  echo "::error::dwarfs-t builtin-baseline ($baseline) != VCPKG_COMMIT ($VCPKG_COMMIT)" >&2; exit 65; }
echo "rust $RUST_VERSION, vcpkg baseline $VCPKG_COMMIT — pinned and in parity"

echo "== env contract =="
for v in VCPKG_ROOT DWARFS_RS_VCPKG_ROOT DWARFS_RS_VCPKG_INSTALLED_DIR \
         SQFS_SYS_VCPKG_INSTALLED_DIR DWARFS_RS_VCPKG_TRIPLET SQFS_SYS_VCPKG_TRIPLET \
         CARGO_NET_GIT_FETCH_WITH_CLI VCPKG_DEFAULT_BINARY_CACHE \
         RUSTUP_HOME CARGO_HOME TPKB_FAMILY TPKB_TRIPLET; do
  eval "val=\${$v:-}"
  [ -n "$val" ] || { echo "::error::env $v is not set" >&2; exit 65; }
  echo "$v=$val"
done
if [ "$TPKB_FAMILY" = "linux-musl" ]; then
  [ "${RUSTFLAGS:-}" = "-C target-feature=-crt-static" ] || {
    echo "::error::RUSTFLAGS must be '-C target-feature=-crt-static' (got '${RUSTFLAGS:-<unset>}')" >&2; exit 65; }
  [ "${VCPKG_FORCE_SYSTEM_BINARIES:-}" = "1" ] || {
    echo "::error::VCPKG_FORCE_SYSTEM_BINARIES must be 1 on musl" >&2; exit 65; }
else
  [ -e "${LIBCLANG_PATH:-/nonexistent}/libclang.so" ] || ls "${LIBCLANG_PATH:-/nonexistent}"/libclang.so* >/dev/null 2>&1 || {
    echo "::error::no libclang.so under LIBCLANG_PATH=${LIBCLANG_PATH:-<unset>}" >&2; exit 65; }
  [ "${CFLAGS:-}" = "-pthread" ] && [ "${CXXFLAGS:-}" = "-pthread" ] || {
    echo "::error::CFLAGS/CXXFLAGS must be -pthread on the glibc floor (the librnp examples link)" >&2; exit 65; }
fi

echo "== vcpkg installed trees =="
test -d "/opt/vcpkg-installed/dwarfs/$VCPKG_TRIPLET" || {
  echo "::error::missing /opt/vcpkg-installed/dwarfs/$VCPKG_TRIPLET" >&2; exit 65; }
test -d "$SQFS_SYS_VCPKG_INSTALLED_DIR/include/sqfs" || {
  echo "::error::missing $SQFS_SYS_VCPKG_INSTALLED_DIR/include/sqfs" >&2; exit 65; }
# `vcpkg list` (classic mode, pointed at the baked roots) — the task's
# `vcpkg list` proof — plus an assert that THIS image's triplet is what
# the trees carry.
/opt/vcpkg/vcpkg list --x-install-root=/opt/vcpkg-installed/dwarfs | head -50
/opt/vcpkg/vcpkg list --x-install-root=/opt/vcpkg-installed/dwarfs | grep -q ":$VCPKG_TRIPLET " || {
  echo "::error::no $VCPKG_TRIPLET packages in the dwarfs tree" >&2; exit 65; }
/opt/vcpkg/vcpkg list --x-install-root=/opt/vcpkg-installed/sqfs | grep ":$VCPKG_TRIPLET " || {
  echo "::error::no $VCPKG_TRIPLET packages in the sqfs tree" >&2; exit 65; }

echo "== baked product binaries =="
# Only tebako-cli owns a --version flag; tfs's bare verb is `help`, the
# rest are presence-checked (their CLIs refuse a bare run with usage).
tebako --version
tfs help >/dev/null
command -v tebako-bootstrap tfs tebako-pkg tebako tebako-shim >/dev/null
# The bootstrap without a trailer prints the Tebako handoff error and
# exits non-zero — the archived v1 images' warm-up did the same check.
tebako-bootstrap 2>&1 | grep -qi tebako || {
  echo "::error::tebako-bootstrap did not produce its handoff error" >&2; exit 65; }

if [ "$TPKB_FAMILY" = "linux-gnu" ]; then
  echo "== glibc floor gate (the baked bootstrap must need <= 2.31) =="
  # The spec 19 §3 rule, mirrored from tebako-rs ci/gnu-floor-build.sh
  # (including its numeric-tail comparison lesson, run 30756664324).
  floor="$(objdump -T /usr/local/bin/tebako-bootstrap \
    | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sort -Vu | tail -1)"
  echo "max glibc symbol version required: ${floor:-none}"
  floor_num="${floor#GLIBC_}"
  if [ -n "$floor_num" ] && [ "$(printf '%s\n2.31\n' "$floor_num" | sort -V | tail -1)" != "2.31" ]; then
    echo "::error::floor violation: the baked bootstrap requires $floor (> 2.31)" >&2
    exit 65
  fi
fi

echo "== factory tooling =="
ruby /opt/tebako-runtime-ruby/tools/build_runtime --help >/dev/null
test -f /opt/tebako-rs/tools/stage_link_unit

if [ "$LIGHT" = "1" ]; then
  echo "smoke (--light): OK"
  exit 0
fi

echo "== probe crate (cold build against the heaviest dep: dwarfs-t-sys) =="
# Copies the probe out of the read-only tree: the build writes target/
# next to the manifest. The vcpkg ports come from the baked layer — what
# this proves is that a consumer's own checkout + this image's env builds
# and links the vendored dwarfs-t C++ closure from a cold target dir.
PROBE_WORK="${TMPDIR:-/tmp}/tpkg-builder-probe"
rm -rf "$PROBE_WORK"
cp -r /opt/tpkg-builder/tools/probe "$PROBE_WORK"
cd "$PROBE_WORK"
cargo build --release
"./target/release/tpkg-builder-probe"

echo "smoke: OK"
