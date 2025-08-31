#!/usr/bin/env bash
set -euo pipefail

# Alpine: musl is system libc; clang/ld.lld installed via apk; libc++ stack installed into /usr
export CC=${CC:-clang}
export CXX=${CXX:-clang++}

# Build a fully static binary using libc++ against system musl
${CXX} -std=c++20 /opt/src/verify.cpp -o /opt/src/verify \
  -O2 -s -static -fuse-ld=lld -stdlib=libc++ -lc++abi -lunwind

# Run once and capture output
OUT=$(/opt/src/verify)
if [[ "$OUT" != "Hello from musl+clang with C++20 (atomic count: 1)" ]]; then
  echo "Unexpected output: $OUT" >&2
  exit 1
fi

# Verify static linking (ldd should report static or not a dynamic executable)
LDD_OUT=$(ldd /opt/src/verify 2>&1 || true)
# Accept common musl outputs for static ELF: "statically linked", "not a dynamic executable",
# or "Not a valid dynamic program" (musl ldd variant)
if [[ "$LDD_OUT" != *"statically linked"* && "$LDD_OUT" != *"not a dynamic executable"* && "$LDD_OUT" != *"Not a valid dynamic program"* ]]; then
  echo "Linkage check failed; binary appears dynamic:" >&2
  echo "$LDD_OUT" >&2
  exit 1
fi

echo "Verification OK: $OUT"
