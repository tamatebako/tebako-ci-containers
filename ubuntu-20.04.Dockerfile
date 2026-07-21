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

# Kept boost/libevent: still required to build the current tebako gem
# (dwarfs tebako-v0.9.0 does find_package(Boost REQUIRED) and vendored folly
# has a hard libevent dependency with no source-build fallback).
# Pruned folly-era packages (libfmt, libdouble-conversion, libgoogle-glog,
# libdwarf, libiberty, libunwind): dwarfs builds fmt itself via FetchContent,
# libdwarfs builds glog/gflags/double-conversion from source when missing,
# and FOLLY_NO_EXCEPTION_TRACER=ON makes libdwarf/libiberty/libunwind unused.
RUN apt-get -y update && \
    apt-get -y install sudo wget git make pkg-config clang-12 clang++-12      \
    autoconf binutils-dev libevent-dev acl-dev libjemalloc-dev                \
    liblz4-dev liblzma-dev libssl-dev libbrotli-dev libelf-dev                \
    libboost-filesystem-dev libboost-program-options-dev libboost-system-dev  \
    libboost-iostreams-dev libboost-date-time-dev libboost-context-dev        \
    libboost-regex-dev libboost-thread-dev libffi-dev libgdbm-dev             \
    libyaml-dev libncurses-dev libreadline-dev libutfcpp-dev libstdc++-10-dev \
    curl zip unzip ninja-build                                                \
    ca-certificates gnupg lsb-release software-properties-common

# C++20 toolchain for tebako v0.15.0 (libtfs v0.12.0, vcpkg): LLVM 18 from
# apt.llvm.org, installed alongside the stock clang-12 and made the default.
# The ubuntu:focal base (glibc 2.31 floor) is intentionally unchanged.
RUN wget -q https://apt.llvm.org/llvm.sh && \
    chmod +x llvm.sh && \
    ./llvm.sh 18 && \
    rm -f llvm.sh

ENV CC=clang-18
ENV CXX=clang++-18

COPY tools /opt/tools

RUN /opt/tools/tools.sh install_cmake && \
    /opt/tools/tools.sh install_ruby

ENV TEBAKO_PREFIX=/root/.tebako
COPY test /root/test

# TODO(tebako v0.15.0): preinstall prebuilt libtfs v0.12.0 here once the
# libtfs release exists (part 2 of the ci-containers refresh).
# TODO(tebako v0.15.0): restore strict warm-up — the current gem (v0.14.0)
# builds the old folly/dwarfs stack which breaks on several platforms
# (that's the flakiness the libtfs migration removes); tolerated until
# the v0.15.0 gem + prebuilt libtfs land.
RUN gem install tebako && \
    (tebako setup -R 3.3.7 && \
    tebako setup -R 3.4.2 && \
    tebako press -R 3.3.7 -r /root/test -e tebako-test-run.rb -o ruby-3.3.7-package && \
    tebako press -R 3.4.2 -r /root/test -e tebako-test-run.rb -o ruby-3.4.2-package && \
    rm ruby-*-package \
    || echo "WARM-UP FAILED (old folly engine; tolerated until tebako v0.15.0 with prebuilt libtfs)")

ENV PS1="\[\]\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ \[\]"
CMD ["bash"]
