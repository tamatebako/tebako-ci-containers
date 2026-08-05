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

# install-rust.sh — the pinned Rust toolchain in uid-agnostic homes.
#
# RUSTUP_HOME/CARGO_HOME live under /opt (not /root) and /opt/cargo is
# world-writable, so the local-dev story (`docker run --user $(id -u)`)
# works: the caller's uid reuses the baked registry cache and may extend
# it. The container's host triple IS the build target on every leg (the
# tebako-rs musl/gnu release scripts do the same), so no --target flag and
# no extra `rustup target add` — rustup installs the host toolchain only.
set -eu

# shellcheck disable=SC1091
. /opt/tpkg-builder/tools/lib.sh
load_pins
check_contract

export RUSTUP_HOME CARGO_HOME
curl -fsSL https://sh.rustup.rs -o /tmp/rustup-init.sh
sh /tmp/rustup-init.sh -y --profile minimal --default-toolchain "$RUST_VERSION"
rm -f /tmp/rustup-init.sh

# clippy/rustfmt: the product workspace's CI gates on both; a builder image
# that cannot run them pushes those legs back to host provisioning.
"$CARGO_HOME/bin/rustup" component add clippy rustfmt

"$CARGO_HOME/bin/rustc" --version
[ "$("$CARGO_HOME/bin/rustc" --version | cut -d' ' -f2)" = "$RUST_VERSION" ] || {
  echo "rustc version drifted from the pin ($RUST_VERSION)" >&2; exit 65; }

chmod -R a+rX /opt/rustup
chmod -R a+w  /opt/cargo
