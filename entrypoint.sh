#!/usr/bin/env bash
set -euo pipefail

export CC=${CC:-clang}
export CXX=${CXX:-clang++}

# Build and run a libc++ C++20 program (dynamic on glibc)
${CXX} -std=c++20 /opt/src/verify.cpp -o /opt/src/verify \
  -O2 -s -fuse-ld=lld -stdlib=libc++ -lc++abi -lunwind

OUT=$(/opt/src/verify)
if [[ "$OUT" != "Hello from musl+clang with C++20 (atomic count: 1)" ]]; then
  echo "Unexpected output: $OUT" >&2
  exit 1
fi

echo "Verification OK: $OUT"

# Build libnode with current toolchain
cd /opt/src/libnode/node
chmod +x ../build.sh
../build.sh
