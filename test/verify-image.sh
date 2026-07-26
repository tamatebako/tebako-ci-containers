#!/usr/bin/env bash
# Post-publish smoke for the new-build-model images (item 14). The expensive
# proof already happened at image build time (the tools/build_runtime
# warm-up); this script verifies the published image carries the interface
# downstream consumers rely on:
#   - the C/C++ toolchain selected by the CC/CXX env vars
#   - cmake, ruby, git for the build driver
#   - the tebako-runtime-ruby build tooling at /opt/tebako-runtime-ruby
#   - the warm-up build prefix (/root/.build) with the prebuilt libtfs
#     deployed and its download cache seeded (runtime-ruby legs reuse it
#     via --prefix /root/.build)
set -euo pipefail

"${CC:?CC env var must be set}" --version | head -1
"${CXX:?CXX env var must be set}" --version | head -1
cmake --version | head -1
ruby --version
git --version

ruby /opt/tebako-runtime-ruby/tools/build_runtime --help >/dev/null

test -f /root/.build/deps/lib/libtfs.a
test -x /root/.build/deps/bin/mkdwarfs
test -d /root/.build/deps/downloads

echo "verify-image: OK"
