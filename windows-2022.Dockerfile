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

# Use the base image with Windows Server Core
FROM mcr.microsoft.com/windows/servercore:ltsc202

ARG RUBY_INSTALLER_VERSION=3.1.6-1
ADD https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-${RUBY_INSTALLER_VERSION}/rubyinstaller-${RUBY_INSTALLER_VERSION}-x64.exe C:\\temp\\rubyinstaller-devkit.exe

RUN C:\\temp\\rubyinstaller-devkit.exe /silent /dir=C:\\Ruby /tasks="modpath"
RUN setx path "%path%;C:\\Ruby\\bin"
RUN ridk enable ucrt64

# Set DevKit bash as the default shell
SHELL ["C:\\Ruby\\msys64\\usr\\bin\\bash.exe", "-l", "-c"]

RUN pacman -Syu --needed --noconfirm git tar bison flex pactoys && \
    pacboy sync --needed --noconfirm cmake:p boost:p diffutils:p   \
    libevent:p double-conversion:p fmt:p glog:p dlfcn:p ninja:p    \
    gtest:p autotools:p ncurses:p toolchain:p openssl:p make:p     \
    libyaml:p libxslt:p

CMD ["ps"]
