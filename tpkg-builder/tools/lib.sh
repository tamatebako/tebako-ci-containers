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

# lib.sh — shared helpers for the tpkg-builder bake/smoke scripts.
# Sourced, never executed directly. POSIX sh (the musl image's /bin/sh is
# busybox ash).

# load_pins: read the baked pin file and assert the image contract env the
# Dockerfiles set from their build args. Every bake script sources this, so
# a missing build-arg fails the first RUN loudly, never mid-bake.
load_pins() {
  # shellcheck disable=SC1091
  . /opt/tpkg-builder/pins.env
  : "${TPKB_FAMILY:?build-arg TPKB_TRIPLET/ENV TPKB_FAMILY missing — build via the publish workflow or pass the build-args (see README)}"
  : "${TPKB_TRIPLET:?build-arg TPKB_TRIPLET missing}"
  : "${VCPKG_TRIPLET:?build-arg VCPKG_TRIPLET missing}"
  : "${RUST_TARGET:?build-arg RUST_TARGET missing}"
}

# derive_arch: the architecture facts from uname -m + TPKB_FAMILY, used to
# CROSS-CHECK the build-arg-derived env (a wrong matrix row or a hand-built
# image with mismatched args fails the smoke, not a consumer).
derive_arch() {
  case "$(uname -m)" in
    x86_64)  ARCH_VCPKG=x64;   ARCH_RUST=x86_64 ;;
    aarch64) ARCH_VCPKG=arm64; ARCH_RUST=aarch64 ;;
    *) echo "unsupported uname -m: $(uname -m)" >&2; exit 64 ;;
  esac
  case "$TPKB_FAMILY" in
    linux-gnu)
      EXPECTED_VCPKG_TRIPLET="$ARCH_VCPKG-linux-static"
      EXPECTED_RUST_TARGET="$ARCH_RUST-unknown-linux-gnu"
      EXPECTED_TPKB_TRIPLET="$ARCH_RUST-linux-gnu"
      ;;
    linux-musl)
      EXPECTED_VCPKG_TRIPLET="$ARCH_VCPKG-linux-musl"
      EXPECTED_RUST_TARGET="$ARCH_RUST-unknown-linux-musl"
      EXPECTED_TPKB_TRIPLET="$ARCH_RUST-linux-musl"
      ;;
    *) echo "unknown TPKB_FAMILY: $TPKB_FAMILY" >&2; exit 64 ;;
  esac
}

# check_contract: derive + compare. Called by the bake scripts and the smoke.
check_contract() {
  derive_arch
  [ "$VCPKG_TRIPLET" = "$EXPECTED_VCPKG_TRIPLET" ] || {
    echo "VCPKG_TRIPLET=$VCPKG_TRIPLET, expected $EXPECTED_VCPKG_TRIPLET for $(uname -m)/$TPKB_FAMILY" >&2; exit 65; }
  [ "$RUST_TARGET" = "$EXPECTED_RUST_TARGET" ] || {
    echo "RUST_TARGET=$RUST_TARGET, expected $EXPECTED_RUST_TARGET" >&2; exit 65; }
  [ "$TPKB_TRIPLET" = "$EXPECTED_TPKB_TRIPLET" ] || {
    echo "TPKB_TRIPLET=$TPKB_TRIPLET, expected $EXPECTED_TPKB_TRIPLET" >&2; exit 65; }
}
