#!/usr/bin/env bash
set -euo pipefail

export TARGET_TRIPLE=${TARGET_TRIPLE:-x86_64-unknown-linux-musl}
export SYSROOT=${SYSROOT:-/opt/musl}
export CC=${CC:-clang-20}
export CXX=${CXX:-clang++-20}
BUILTINS_DIR="${SYSROOT}/lib/linux"
CRT1="${SYSROOT}/lib/crt1.o"
CRTI="${SYSROOT}/lib/crti.o"
CRTN="${SYSROOT}/lib/crtn.o"

# Compile statically with libc++ and libc++abi from the musl sysroot.
# Compile only with libc++ headers from the musl sysroot
${CXX} -std=c++20 -c /opt/src/verify.cpp -o /opt/src/verify.o \
  --target=${TARGET_TRIPLE} --sysroot=${SYSROOT} \
  -nostdinc++ -I"${SYSROOT}/include/c++/v1" -O2

# Link statically with musl CRTs, libc++ stack, libc, and compiler-rt builtins using ld.lld
/usr/bin/ld.lld-20 -o /opt/src/verify -static \
  "${CRT1}" "${CRTI}" \
  /opt/src/verify.o \
  -L"${SYSROOT}/lib" -L"${SYSROOT}/lib/${TARGET_TRIPLE}" -L"${BUILTINS_DIR}" \
  --start-group -lc++ -lc++abi -lunwind -lc -lm -lpthread -l:libclang_rt.builtins-x86_64.a --end-group \
  "${CRTN}" \
  -s

# Run once and capture output
OUT=$(/opt/src/verify)
if [[ "$OUT" != "Hello from musl+clang with C++20" ]]; then
  echo "Unexpected output: $OUT" >&2
  exit 1
fi

# Verify static linking (ldd should report static or not a dynamic executable)
LDD_OUT=$(ldd /opt/src/verify 2>&1 || true)
if [[ "$LDD_OUT" != *"statically linked"* && "$LDD_OUT" != *"not a dynamic executable"* ]]; then
  echo "Linkage check failed; binary appears dynamic:" >&2
  echo "$LDD_OUT" >&2
  exit 1
fi

echo "Verification OK: $OUT"
