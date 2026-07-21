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

# Toolchain note: alpine 3.17 ships gcc-12 and clang-15 (with gcc-12's
# libstdc++), both of which compile the C++20 tebako codebase today, so no
# toolchain change is needed here. Base kept at 3.17: the container tag and
# downstream tebako CI (tebako-alpine-3.17-dev images) are tied to it.
# Pruned folly-era packages (fmt, gflags, libdwarf, libunwind): dwarfs builds
# fmt itself via FetchContent, libdwarfs builds glog/gflags/double-conversion
# from source when missing, and FOLLY_NO_EXCEPTION_TRACER=ON makes
# libdwarf/libunwind unused. boost/libevent stay (hard build requirements).
RUN apk --no-cache --upgrade add build-base cmake git bash sudo  \
    autoconf boost-static boost-dev flex-dev bison make clang    \
    binutils-dev libevent-dev acl-dev sed python3 pkgconfig curl \
    lz4-dev openssl-dev zlib-dev xz ninja zip unzip tar xz-dev   \
    elfutils-dev gcompat libffi-dev xz-static                    \
    libevent-static openssl-libs-static lz4-static               \
    zlib-static acl-static gdbm-dev yaml-dev yaml-static         \
    ncurses-dev ncurses-static p7zip ruby-dev jemalloc-dev       \
    readline-dev readline-static gettext-dev gperf               \
    brotli-dev brotli-static libxslt-dev libxslt-static

ENV CC=clang
ENV CXX=clang++

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

ENV PS1="\[\]\[\e]0;\u@\h: \w\a\]\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ \[\]"
CMD ["bash"]
