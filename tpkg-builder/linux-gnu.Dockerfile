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

# tpkg-builder-{x86_64,aarch64}-linux-gnu — the glibc-floor slice builder.
#
# FROM ubuntu:20.04 makes the glibc 2.31 floor a FACT (spec 19 §3): glibc
# symbol versions are one-directional, so anything built here runs on
# 20.04 and everything newer. This is what tebako-rs's release legs
# already do by hand (ci/gnu-floor-build.sh inside a plain ubuntu:20.04
# container); the image turns the discipline into the base layer.
#
# The provisioning mirrors that proven script: clang-19/libclang from
# apt.llvm.org (bindgen), gcc-11 from the toolchain-r ppa (rnp-src's
# Botan 3 hard-gates on gcc >= 11 and a C++20 stdlib; focal main tops out
# at gcc 10), -pthread driver flags (glibc 2.31's separate libpthread vs
# librnp's unconditional examples), Kitware's cmake tarball, then the
# shared bake (tools/*.sh). The package list is the union of the release
# script's and the archived v1 image's (the runtime factory's ruby build
# links libacl.a/libjemalloc.a statically — keep the dev packages).
# libgmp-dev is for ruby-install: its apt dependency list includes it
# unconditionally for ruby > 2.1, and it auto-installs anything missing —
# with the apt lists cleaned above, an unmet dep fails the build
# ("Unable to locate package"); every ruby-install dep is preinstalled
# here so its scan is a no-op.

FROM ubuntu:20.04

# Cache invalidation for scheduled refreshes: the workflow passes the run
# date, busting every layer from here down so the weekly rebuild picks up
# base-image and apt drift. Manual/PR builds pass nothing (cache-friendly).
ARG CACHEBUST=0

# Per-triplet contract, passed by the publish workflow (matrix). No
# defaults: a hand build without them fails loudly at the first bake RUN.
ARG TPKB_TRIPLET
ARG VCPKG_TRIPLET
ARG RUST_TARGET

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# The pins first: every versioned layer below sources them.
COPY tpkg-builder/pins.env /opt/tpkg-builder/pins.env

RUN echo "$CACHEBUST" > /etc/tpkg-builder-build-stamp && \
    apt-get -y update && \
    apt-get -y install --no-install-recommends \
      build-essential cmake ninja-build pkg-config \
      autoconf automake autoconf-archive libtool \
      curl wget zip unzip tar xz-utils bzip2 ca-certificates git gnupg lsb-release \
      sudo make ruby \
      libbz2-dev \
      libffi-dev libgdbm-dev zlib1g-dev libyaml-dev libncurses-dev \
      libreadline-dev libssl-dev libacl1-dev libjemalloc-dev libgmp-dev && \
    git config --system --add safe.directory '*' && \
    rm -rf /var/lib/apt/lists/*

# git safe.directory '*': bind-mounted workspaces are owned by the
# caller's uid, and git >= 2.35.2 otherwise refuses them as "dubious
# ownership" — dwarfs-t's cmake/version.cmake then sees no metadata and
# dies (tebako-rs runs 30742821370/30750321798). System config covers
# every uid the image runs as.

# clang-19 + libclang-19 (llvm.org apt): rnp-rs's build.rs runs bindgen,
# which dlopens libclang.so; focal's stock libclang (v10) is too old for
# the current bindgen. Not the compiler — gcc-11 below is.
RUN curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor -o /usr/share/keyrings/llvm.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/llvm.gpg] http://apt.llvm.org/focal/ llvm-toolchain-focal-19 main" \
      > /etc/apt/sources.list.d/llvm19.list && \
    apt-get -y update && \
    apt-get -y install --no-install-recommends clang-19 libclang-19-dev && \
    echo "/usr/lib/llvm-19/lib" > /etc/ld.so.conf.d/llvm19.conf && \
    ldconfig && \
    rm -rf /var/lib/apt/lists/*

# gcc-11 (ubuntu-toolchain-r ppa), made the default by name: rnp-src pins
# the librnp compiler by NAME (gcc/g++), so the names resolve to gcc-11.
# libstdc++ is absorbed statically into the shipped binaries, so the
# ppa's newer libstdc++ adds no runtime floor — the GLIBC gate stays the
# arbiter. Key 1E9377A2BA9EF27F is the ppa's published signer; the
# key+deb-line form (no add-apt-repository API call) works on both arches
# (the launchpad lookup hangs ~9 min then dies on arm64 — run 30745532174).
RUN curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x1E9377A2BA9EF27F" \
      | gpg --dearmor -o /usr/share/keyrings/toolchainr.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/toolchainr.gpg] http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu focal main" \
      > /etc/apt/sources.list.d/toolchainr.list && \
    apt-get -y update && \
    apt-get -y install --no-install-recommends gcc-11 g++-11 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 110 \
      --slave /usr/bin/g++ g++ /usr/bin/g++-11 && \
    update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-11 110 && \
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-11 110 && \
    g++ --version | head -1 && \
    rm -rf /var/lib/apt/lists/*

# cmake from the Kitware release tarball (arch-exact, runs on focal's
# glibc): dwarfs-t's cmake_minimum_required is 3.28, focal's stock is
# 3.16. Shadows the apt one via /usr/local/bin.
RUN . /opt/tpkg-builder/pins.env && \
    cmake_arch=x86_64; [ "$(uname -m)" = "aarch64" ] && cmake_arch=aarch64; \
    curl -fsSL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${cmake_arch}.tar.gz" \
      | tar -xz -C /opt && \
    ln -sfn "/opt/cmake-${CMAKE_VERSION}-linux-${cmake_arch}/bin/cmake" /usr/local/bin/cmake && \
    ln -sfn "/opt/cmake-${CMAKE_VERSION}-linux-${cmake_arch}/bin/ctest" /usr/local/bin/ctest && \
    ln -sfn "/opt/cmake-${CMAKE_VERSION}-linux-${cmake_arch}/bin/cpack" /usr/local/bin/cpack && \
    cmake --version | head -1

# Toolchain ruby via ruby-install (focal's apt ruby is 2.7; feedstock
# tools and the factory tooling need >= 3). Tooling-only — never linked.
RUN . /opt/tpkg-builder/pins.env && \
    curl -fsSL -o /tmp/ruby-install.tar.gz \
      "https://github.com/postmodern/ruby-install/releases/download/v${RUBY_INSTALL_VERSION}/ruby-install-${RUBY_INSTALL_VERSION}.tar.gz" && \
    tar -xzf /tmp/ruby-install.tar.gz -C /tmp && \
    make -C "/tmp/ruby-install-${RUBY_INSTALL_VERSION}" install && \
    ruby-install --system ruby "$RUBY_TOOLCHAIN_VERSION" -- \
      --without-gmp --disable-dtrace --disable-debug-env --disable-install-doc && \
    rm -rf /tmp/ruby-install* && \
    ruby --version

# patchelf from source (focal's 0.10 is too old): the runtime factory's
# --patchelf pass and general RPATH surgery.
RUN . /opt/tpkg-builder/pins.env && \
    curl -fsSL -o /tmp/patchelf.tar.bz2 \
      "https://github.com/NixOS/patchelf/releases/download/${PATCHELF_VERSION}/patchelf-${PATCHELF_VERSION}.tar.bz2" && \
    tar -xjf /tmp/patchelf.tar.bz2 -C /tmp && \
    cd "/tmp/patchelf-${PATCHELF_VERSION}" && \
    ./configure && make -j"$(nproc)" && make install && \
    cd / && rm -rf /tmp/patchelf* && \
    patchelf --version

# -----------------------------------------------------------------------
# The baked environment contract (consumer legs read exactly this).
# -----------------------------------------------------------------------
ENV TPKB_FAMILY=linux-gnu \
    TPKB_TRIPLET=$TPKB_TRIPLET \
    RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/sbin:/bin \
    CARGO_NET_GIT_FETCH_WITH_CLI=true \
    VCPKG_ROOT=/opt/vcpkg \
    VCPKG_DEFAULT_BINARY_CACHE=/opt/vcpkg-cache \
    DWARFS_RS_VCPKG_ROOT=/opt/vcpkg \
    DWARFS_RS_VCPKG_INSTALLED_DIR=/opt/vcpkg-installed/dwarfs \
    DWARFS_RS_VCPKG_TRIPLET=$VCPKG_TRIPLET \
    SQFS_SYS_VCPKG_INSTALLED_DIR=/opt/vcpkg-installed/sqfs/$VCPKG_TRIPLET \
    SQFS_SYS_VCPKG_TRIPLET=$VCPKG_TRIPLET \
    LIBCLANG_PATH=/usr/lib/llvm-19/lib \
    CFLAGS=-pthread \
    CXXFLAGS=-pthread
# LIBCLANG_PATH: bindgen dlopens libclang at build time.
# CFLAGS/CXXFLAGS=-pthread: glibc 2.31 keeps pthreads in a separate
# libpthread and librnp builds its examples unconditionally with no
# find_package(Threads); as DRIVER flags these are order-immune
# (run 30748661257). vcpkg's own toolchain overrides them for its ports.

# The bake: pinned rust, vcpkg at the baseline, the installed trees, the
# product binaries, the factory tooling. Each script is POSIX sh.
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

ENV PS1="\[\]\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ \[\]"
CMD ["bash"]
