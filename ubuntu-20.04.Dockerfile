# Copyright (c) 2024 [Ribose Inc](https://www.ribose.com).
# All rights reserved.
# This file is a part of tamatebako
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
ENV ARCH=x64

RUN apt-get -y update && \
    apt-get -y install sudo wget git make pkg-config gcc-10 g++-10            \
    autoconf binutils-dev libevent-dev acl-dev libfmt-dev libjemalloc-dev     \
    libdouble-conversion-dev libiberty-dev liblz4-dev liblzma-dev libssl-dev  \
    libboost-filesystem-dev libboost-program-options-dev libboost-system-dev  \
    libboost-iostreams-dev  libboost-date-time-dev libboost-context-dev       \
    libboost-regex-dev libboost-thread-dev libbrotli-dev libunwind-dev        \
    libdwarf-dev libelf-dev libgoogle-glog-dev libffi-dev libgdbm-dev         \
    libyaml-dev libncurses-dev libreadline-dev libutfcpp-dev libstdc++-10-dev

ENV CC=clang-12
ENV CXX=clang++-12

COPY tools /opt/tools

RUN /opt/tools/tools.sh install_cmake && \
    /opt/tools/tools.sh install_ruby

# https://github.com/actions/checkout/issues/1014
# RUN adduser --disabled-password --gecos "" --home $HOME tebako && \
#    printf "\ntebako\tALL=(ALL)\tNOPASSWD:\tALL" > /etc/sudoers.d/tebako
# USER tebako
# ENV HOME=/home/tebako

# So we are running as root, HOME=/root, tebako prefix (default) /root/.tebako

ENV TEBAKO_PREFIX=/root/.tebako
COPY test /root/test

# Create packaging environment for Ruby 3.3.4, 3.2.5
# Test and "warm up" since initialization is fully finished after the first packaging
RUN gem install tebako && \
    tebako setup -R 3.3.4 && \
    tebako setup -R 3.2.5 && \
    tebako press -R 3.3.4 -r /root/test -e tebako-test-run.rb -o ruby-3.3.4-package && \
    tebako press -R 3.2.5 -r /root/test -e tebako-test-run.rb -o ruby-3.2.5-package && \
    rm ruby-*-package

ENV PS1="\[\]\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ \[\]"
CMD ["bash"]
