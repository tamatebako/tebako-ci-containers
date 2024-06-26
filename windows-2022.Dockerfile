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

FROM microsoft/windowsservercore
# FROM microsoft/nanoserver

# Download base ruby
RUN powershell \
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-2.4.6-1/rubyinstaller-devkit-2.4.6-1-x64.exe -Outfile rubyinstaller.exe
# Download git
RUN powershell \
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest https://github.com/git-for-windows/git/releases/download/v2.20.1.windows.1/Git-2.20.1-64-bit.exe -Outfile git-installer.exe
# Download Inno Setup    
RUN powershell \
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest http://www.jrsoftware.org/download.php/is.exe -Outfile inno-setup.exe
    
# Install base ruby and initialize Devkit
RUN (cmd /c rubyinstaller.exe /verysilent /log=install.log) || (powershell get-content c:/install.log)
RUN powershell $env:PATH = [Environment]::GetEnvironmentVariable('PATH','Machine'); \
    $env:RUBYOPT = [Environment]::GetEnvironmentVariable('RUBYOPT','Machine')
RUN ruby --version
RUN ridk install 1

# Install git
RUN cmd /c git-installer.exe /verysilent
RUN git --version

# Install Inno Setup
RUN cmd /c inno-setup.exe /verysilent /allusers
RUN powershell [Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';c:/Program Files (x86)/Inno Setup 6', 'Machine')
RUN iscc --version || (exit 0)

RUN ridk enable
# Set DevKit bash as the default shell
SHELL ["C:\\Ruby\\msys64\\usr\\bin\\bash.exe", "-l", "-c"]

RUN pacman -Syu --needed --noconfirm git tar bison flex pactoys && \
    pacboy sync --needed --noconfirm cmake:p boost:p diffutils:p   \
    libevent:p double-conversion:p fmt:p glog:p dlfcn:p ninja:p    \
    gtest:p autotools:p ncurses:p toolchain:p openssl:p make:p     \
    libyaml:p libxslt:p

CMD ["ps"]
