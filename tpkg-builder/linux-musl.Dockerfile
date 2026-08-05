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

# tpkg-builder-{x86_64,aarch64}-linux-musl — the musl slice builder.
#
# FROM alpine:3.21: the native-musl path tebako-rs's release legs prove
# (ci/musl-build.sh — node actions cannot run on musl, so the legs docker
# run alpine:3.21 and provision in-leg; the image IS that provisioning,
# baked). alpine 3.21's apk cmake is 3.31.x, clearing the boost-1.90-era
# >= 3.25 floor, so no source-built cmake (the archived 3.17-generation
# image needed one; the plan's "cmake from source" targeted that
# generation — see README).
#
# The two musl-specific env contracts, straight from musl-build.sh:
#   VCPKG_FORCE_SYSTEM_BINARIES=1 — vcpkg's downloaded cmake/ninja are
#     glibc-linked (exit 127 on musl); use the apk tools everywhere.
#   RUSTFLAGS=-C target-feature=-crt-static — musl targets default to
#     +crt-static and a statically linked build script cannot dlopen, but
#     rnp-rs's build.rs runs bindgen (libclang). Artifacts are
#     dynamic-musl, the same shape as the runtime factory's musl
#     runtimes (musl libc is present on every musl system by definition).
# The flag is baked as an env so it reaches HOST build scripts (the
# --target RUSTFLAGS trap, tebako-rs run 30745532174 — consumer legs must
# build WITHOUT --target inside this image, as build-product.sh does).

FROM alpine:3.21

# Cache invalidation for scheduled refreshes (see linux-gnu.Dockerfile).
ARG CACHEBUST=0

# Per-triplet contract, passed by the publish workflow (matrix).
ARG TPKB_TRIPLET
ARG VCPKG_TRIPLET
ARG RUST_TARGET

ENV TZ=Etc/UTC

# The pins first: every versioned layer below sources them.
COPY tpkg-builder/pins.env /opt/tpkg-builder/pins.env

# The union of tebako-rs ci/musl-build.sh's apk list (the v2-proven set)
# and the archived v1 alpine image's (the runtime factory's ruby build
# links the *-static packages). gcompat is deliberately dropped: nothing
# glibc-linked runs in the v2 musl path (VCPKG_FORCE_SYSTEM_BINARIES=1;
# flatc & co build from source and run natively — the reason this is not
# a cross-compile leg).
RUN echo "$CACHEBUST" > /etc/tpkg-builder-build-stamp && \
    apk --no-cache --upgrade add \
      build-base cmake ninja git bash sudo \
      autoconf automake libtool make pkgconfig perl python3 \
      curl zip unzip tar ca-certificates linux-headers \
      ruby ruby-dev \
      clang19 clang19-libclang \
      flex-dev bison binutils-dev sed elfutils-dev \
      acl-dev acl-static libffi-dev gdbm-dev \
      yaml-dev yaml-static ncurses-dev ncurses-static \
      readline-dev readline-static zlib-dev zlib-static \
      openssl-dev openssl-libs-static lz4-dev lz4-static \
      xz xz-dev xz-static brotli-dev brotli-static \
      libxslt-dev libxslt-static jemalloc-dev gettext-dev gperf p7zip && \
    git config --system --add safe.directory '*'
# clang19-libclang: bindgen (rnp-rs's build.rs) dlopens libclang.so at
# build time; only the versioned libclang package ships it on alpine.
# clang19 (the compiler) rides along for consumers that opt into
# CC=clang-19; the v2 default toolchain is build-base's gcc (rnp-src pins
# gcc/g++ by name, and alpine 3.21's gcc 14 clears Botan 3's >= 11 gate).
#
# git safe.directory '*': bind-mounted workspaces are owned by the
# caller's uid; git >= 2.35.2 otherwise refuses them as "dubious
# ownership" and dwarfs-t's cmake/version.cmake dies (run 30742821370).

# -----------------------------------------------------------------------
# The baked environment contract (consumer legs read exactly this).
# -----------------------------------------------------------------------
ENV TPKB_FAMILY=linux-musl \
    TPKB_TRIPLET=$TPKB_TRIPLET \
    RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/sbin:/bin \
    CARGO_NET_GIT_FETCH_WITH_CLI=true \
    RUSTFLAGS="-C target-feature=-crt-static" \
    VCPKG_FORCE_SYSTEM_BINARIES=1 \
    VCPKG_ROOT=/opt/vcpkg \
    VCPKG_DEFAULT_BINARY_CACHE=/opt/vcpkg-cache \
    DWARFS_RS_VCPKG_ROOT=/opt/vcpkg \
    DWARFS_RS_VCPKG_INSTALLED_DIR=/opt/vcpkg-installed/dwarfs \
    DWARFS_RS_VCPKG_TRIPLET=$VCPKG_TRIPLET \
    SQFS_SYS_VCPKG_INSTALLED_DIR=/opt/vcpkg-installed/sqfs/$VCPKG_TRIPLET \
    SQFS_SYS_VCPKG_TRIPLET=$VCPKG_TRIPLET \
    VCPKG_TRIPLET=$VCPKG_TRIPLET

# The bake: pinned rust (+musl host target by construction), vcpkg at the
# baseline, the overlay triplets + installed trees, the product binaries,
# the factory tooling. Each script is POSIX sh.
COPY tpkg-builder/tools /opt/tpkg-builder/tools
RUN sh /opt/tpkg-builder/tools/install-rust.sh
RUN sh /opt/tpkg-builder/tools/install-vcpkg.sh
RUN sh /opt/tpkg-builder/tools/bake-vcpkg-trees.sh
RUN sh /opt/tpkg-builder/tools/build-product.sh
RUN sh /opt/tpkg-builder/tools/bake-factory-tooling.sh

# The build-time gate is the light form (interface + contract asserts);
# the publish workflow runs the FULL smoke (with the probe-crate build)
# against the loaded image before anything is pushed.
RUN sh /opt/tpkg-builder/tools/smoke.sh --light

ENV PS1="\[\]\[\e]0;\u@\h: \w\a\]\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ \[\]"
CMD ["/bin/bash"]
