# Copyright (c) 2024-2025 [Ribose Inc](https://www.ribose.com).
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

FROM alpine:3.17

ENV TZ=Etc/UTC
ENV ARCH=x64

# New build model (tebako-ci-containers item 14): the image serves
# tebako-runtime-ruby's tools/build_runtime against the PREBUILT libtfs /
# libtfs-deps musl packages — no tebako gem, no patch layer. The dwarfs-era
# packages (boost, libevent) are gone; the musl static dev packages the
# patched-ruby build links against stay.
# Toolchain note: alpine 3.17 ships gcc-12 and clang-15 (with gcc-12's
# libstdc++), both of which compile the C++20 tebako codebase today, so no
# toolchain change is needed here. Base kept at 3.17: the container tag and
# downstream tebako CI (tebako-alpine-3.17-dev images) are tied to it.
RUN apk --no-cache --upgrade add build-base cmake git bash sudo  \
    autoconf automake flex-dev bison make clang                  \
    binutils-dev acl-dev sed python3 pkgconfig curl              \
    lz4-dev openssl-dev zlib-dev xz ninja zip unzip tar xz-dev   \
    elfutils-dev gcompat libffi-dev xz-static                    \
    openssl-libs-static lz4-static                               \
    zlib-static acl-static gdbm-dev yaml-dev yaml-static         \
    ncurses-dev ncurses-static p7zip ruby-dev jemalloc-dev       \
    readline-dev readline-static gettext-dev gperf               \
    brotli-dev brotli-static libxslt-dev libxslt-static

ENV CC=clang
ENV CXX=clang++

# The tebako-runtime-ruby build tooling (pinned to the runtime contract
# version the image is built for). Runtime-ruby CI legs may mount their own
# checkout at /mnt/w and call /mnt/w/tools/build_runtime; this baked copy is
# what the warm-up below and /opt/verify-image.sh exercise.
ARG TEBAKO_RUNTIME_RUBY_REF=v0.15.9
RUN wget -q -O /tmp/tebako-runtime-ruby.tar.gz \
      https://codeload.github.com/tamatebako/tebako-runtime-ruby/tar.gz/refs/tags/${TEBAKO_RUNTIME_RUBY_REF} && \
    mkdir -p /opt/tebako-runtime-ruby && \
    tar -xzf /tmp/tebako-runtime-ruby.tar.gz -C /opt/tebako-runtime-ruby --strip-components=1 && \
    rm -f /tmp/tebako-runtime-ruby.tar.gz

COPY test/verify-image.sh /opt/verify-image.sh

# Warm-up: build one runtime package end-to-end with the new model (no
# --patchelf: that is a glibc-only step). This validates the toolchain, the
# libtfs prebuilt-package fetch (SHA256-verified) and the patched-ruby build,
# and seeds /root/.build — the prefix runtime-ruby legs pass as --prefix
# /root/.build ("the container image is the cache"). The produced package is
# executed without an image to prove the binary runs (it must print the
# Tebako handoff error and exit non-zero), then removed together with the
# top-level CMake build dir: what stays in /root/.build is autotools/copied
# state only (libtfs deployment, ruby build tree, download caches), nothing
# that references the baked tooling path.
RUN ruby /opt/tebako-runtime-ruby/tools/build_runtime --ruby 3.3.7 \
      --prefix /root/.build --output /root/warmup/tebako-runtime-warmup && \
    test -x /root/warmup/tebako-runtime-warmup && \
    /root/warmup/tebako-runtime-warmup 2>&1 | grep -q "Tebako" && \
    rm -rf /root/warmup /root/.build/o

ENV PS1="\[\]\[\e]0;\u@\h: \w\a\]\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ \[\]"
CMD ["bash"]
