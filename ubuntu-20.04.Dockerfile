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

FROM ubuntu:focal

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ARG ARCH=x64

# New build model (tebako-ci-containers item 14): the image serves
# tebako-runtime-ruby's tools/build_runtime — a CMake driver that builds the
# runtime package from the pre-patched ruby source (tamatebako/ruby release)
# against the PREBUILT libtfs/libtfs-deps packages. There is no tebako gem
# and no patch layer in the image, so the dwarfs-era build dependencies
# (boost, libevent, libdwarf/libelf, double-conversion, glog, fmt, utfcpp,
# lz4/lzma/brotli dev packages) are gone; what remains is the toolchain,
# the autotools chain (patchelf bootstraps from git), and the dev packages
# the ruby build itself links against.
RUN apt-get -y update && \
    apt-get -y install sudo wget git make pkg-config clang-12 clang++-12   \
    autoconf automake binutils libffi-dev libgdbm-dev zlib1g-dev           \
    libyaml-dev libncurses-dev libreadline-dev libssl-dev libstdc++-10-dev \
    curl zip unzip ninja-build                                             \
    ca-certificates gnupg lsb-release software-properties-common

# C++20 toolchain for the libtfs v0.13.0 contract: LLVM 18 from apt.llvm.org,
# installed alongside the stock clang-12 and made the default. The ubuntu:focal
# base (glibc 2.31 floor) is intentionally unchanged.
RUN wget -q https://apt.llvm.org/llvm.sh && \
    chmod +x llvm.sh && \
    ./llvm.sh 18 && \
    rm -f llvm.sh

ENV CC=clang-18
ENV CXX=clang++-18

COPY tools /opt/tools

RUN /opt/tools/tools.sh install_cmake && \
    /opt/tools/tools.sh install_ruby

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

# Warm-up: build one runtime package end-to-end with the new model. This
# validates the toolchain, the libtfs prebuilt-package fetch (SHA256-verified)
# and the patched-ruby build, and seeds /root/.build (deps + download cache)
# that runtime-ruby legs reuse via --prefix /root/.build. The package is
# executed without an image to prove the produced binary runs (it must print
# the Tebako handoff error and exit non-zero), then removed.
RUN ruby /opt/tebako-runtime-ruby/tools/build_runtime --ruby 3.3.7 \
      --prefix /root/.build --output /root/warmup/tebako-runtime-warmup --patchelf && \
    test -x /root/warmup/tebako-runtime-warmup && \
    /root/warmup/tebako-runtime-warmup 2>&1 | grep -q "Tebako" && \
    rm -rf /root/warmup

ENV PS1="\[\]\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ \[\]"
CMD ["bash"]
