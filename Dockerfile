## Alpine base with Clang + musl + libc++ as system defaults
FROM alpine:3.22.1

ARG LLVM_RUNTIMES_VERSION=20.1.0
ENV TZ=Etc/UTC \
  TARGET_TRIPLE=x86_64-alpine-linux-musl \
  CC=clang \
  CXX=clang++ \
  LLVM_RUNTIMES_VERSION=${LLVM_RUNTIMES_VERSION}

# Install base build tools, clang/lld, and headers
RUN set -eux; \
  apk add --no-cache \
  bash coreutils ca-certificates tzdata \
  build-base cmake ninja \
  clang lld llvm-dev llvm20-static \
  compiler-rt \
  linux-headers \
  curl git xz tar python3;

## Build libc++ stack (libunwind, libc++abi, libc++) and install into /usr (system default)
WORKDIR /tmp
RUN set -eux; \
  RVER=${LLVM_RUNTIMES_VERSION}; \
  curl -fsSL -o llvm-project.tar.xz https://github.com/llvm/llvm-project/releases/download/llvmorg-${RVER}/llvm-project-${RVER}.src.tar.xz; \
  tar -xf llvm-project.tar.xz; \
  cmake -S llvm-project-${RVER}.src/runtimes -B /tmp/llvm-musl-build -G Ninja \
  -DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx" \
  -DLLVM_TARGETS_TO_BUILD="X86" \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DCMAKE_C_COMPILER=${CC} \
  -DCMAKE_CXX_COMPILER=${CXX} \
  -DLLVM_USE_LINKER=lld \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLIBUNWIND_ENABLE_SHARED=OFF \
  -DLIBUNWIND_ENABLE_STATIC=ON \
  -DLIBUNWIND_ENABLE_TESTS=OFF \
  -DLIBUNWIND_ENABLE_EXAMPLES=OFF \
  -DLIBUNWIND_ENABLE_DOCS=OFF \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBCXXABI_ENABLE_STATIC=ON \
  -DLIBCXXABI_USE_COMPILER_RT=ON \
  -DLIBCXXABI_ENABLE_TESTS=OFF \
  -DLIBCXXABI_ENABLE_DOCS=OFF \
  -DLIBCXXABI_HAS_CXA_THREAD_ATEXIT_IMPL=OFF \
  -DLIBCXX_ENABLE_SHARED=OFF \
  -DLIBCXX_ENABLE_STATIC=ON \
  -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF \
  -DLIBCXX_ENABLE_FILESYSTEM=ON \
  -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=OFF \
  -DLIBCXX_USE_COMPILER_RT=ON \
  -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXX_HAS_MUSL_LIBC=ON \
  -DLIBCXX_INCLUDE_BENCHMARKS=OFF; \
  cmake --build /tmp/llvm-musl-build --target install -j"$(nproc)"; \
  rm -rf /tmp/llvm-project* /tmp/llvm-musl-build

# Add verification source and entrypoint
WORKDIR /opt/src
COPY verify.cpp /opt/src/verify.cpp
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Make libc++ the default C++ standard library for clang via system config
RUN set -eux; \
  mkdir -p /etc/clang; \
  printf "-stdlib=libc++\n-unwindlib=libunwind\n-rtlib=compiler-rt\n-fuse-ld=lld\n" > /etc/clang/clang.cfg

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
