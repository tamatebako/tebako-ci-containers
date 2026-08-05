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

# bake-factory-tooling.sh — the tebako-runtime-ruby build tooling
# (tools/build_runtime) at /opt/tebako-runtime-ruby, so the factory POSIX
# legs can run the whole build — link-unit staging, ruby, image packaging
# — inside ONE image (TODO.v2-1/13 step 2). Factory legs may still mount
# their own checkout and call its tools/ directly; the baked copy is the
# pinned fallback and the smoke's wiring check.
set -eu

# shellcheck disable=SC1091
. /opt/tpkg-builder/tools/lib.sh
load_pins

# A codeload tarball, not a git clone: the tooling is executed, never
# developed, inside the image.
curl -fsSL -o /tmp/tebako-runtime-ruby.tar.gz \
  "https://codeload.github.com/tamatebako/tebako-runtime-ruby/tar.gz/$TEBAKO_RUNTIME_RUBY_REF"
mkdir -p /opt/tebako-runtime-ruby
tar -xzf /tmp/tebako-runtime-ruby.tar.gz -C /opt/tebako-runtime-ruby --strip-components=1
rm -f /tmp/tebako-runtime-ruby.tar.gz

# Wiring check (the archived v1 images' verify-image.sh did the same):
# the tooling parses and its CLI answers.
ruby /opt/tebako-runtime-ruby/tools/build_runtime --help >/dev/null

chmod -R a+rX /opt/tebako-runtime-ruby
