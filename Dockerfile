FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG LLVM_VERSION=20
ARG LLVM_RUNTIMES_VERSION=20.1.0

ENV TZ=Etc/UTC \
  TARGET_TRIPLE=x86_64-unknown-linux-musl \
  SYSROOT=/opt/musl \
  CC=clang-20 \
  CXX=clang++-20

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg software-properties-common \
  build-essential cmake ninja-build pkg-config \
  python3 git xz-utils file linux-libc-dev; \
  install -d -m 0755 /etc/apt/keyrings; \
  curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor >/etc/apt/keyrings/apt.llvm.org.gpg; \
  echo "deb [signed-by=/etc/apt/keyrings/apt.llvm.org.gpg] http://apt.llvm.org/noble/ llvm-toolchain-noble-${LLVM_VERSION} main" >/etc/apt/sources.list.d/llvm.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  clang-${LLVM_VERSION} lld-${LLVM_VERSION} lldb-${LLVM_VERSION}; \
  update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${LLVM_VERSION} 50; \
  update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${LLVM_VERSION} 50; \
  update-alternatives --install /usr/bin/lld lld /usr/bin/lld-${LLVM_VERSION} 50; \
  rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN set -eux; \
  MUSL_VER=1.2.5; \
  curl -fsSL https://musl.libc.org/releases/musl-${MUSL_VER}.tar.gz -o musl.tar.gz; \
  tar -xzf musl.tar.gz; \
  cd musl-${MUSL_VER}; \
  ./configure --prefix=${SYSROOT} --disable-shared; \
  make -j"$(nproc)"; \
  make install; \
  cd /tmp; rm -rf musl-* musl.tar.gz

WORKDIR /tmp
RUN set -eux; \
  RVER=${LLVM_RUNTIMES_VERSION}; \
  curl -fsSL -o llvm-project.tar.xz \
  https://github.com/llvm/llvm-project/releases/download/llvmorg-${RVER}/llvm-project-${RVER}.src.tar.xz; \
  tar -xf llvm-project.tar.xz; \
  cmake -S llvm-project-${RVER}.src/compiler-rt -B /tmp/llvm-crt-build -G Ninja \
  -DCMAKE_INSTALL_PREFIX=${SYSROOT} \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DCMAKE_C_COMPILER=${CC} \
  -DCMAKE_C_COMPILER_TARGET=${TARGET_TRIPLE} \
  -DCMAKE_ASM_COMPILER=${CC} \
  -DCMAKE_SYSROOT=${SYSROOT} \
  -DLLVM_USE_LINKER=lld \
  -DCMAKE_C_FLAGS="--target=${TARGET_TRIPLE} --sysroot=${SYSROOT}" \
  -DCOMPILER_RT_BUILD_BUILTINS=ON \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
  -DCOMPILER_RT_BAREMETAL_BUILD=ON \
  -DCOMPILER_RT_BUILD_TESTS=OFF \
  -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
  -DCOMPILER_RT_BUILD_XRAY=OFF \
  -DCOMPILER_RT_BUILD_PROFILE=OFF \
  -DCOMPILER_RT_BUILD_MEMPROF=OFF; \
  cmake --build /tmp/llvm-crt-build --target install-builtins -j"$(nproc)"; \
  rm -rf /tmp/llvm-crt-build

WORKDIR /tmp
RUN set -eux; \
  RVER=${LLVM_RUNTIMES_VERSION}; \
  if [ ! -d /tmp/llvm-project-${RVER}.src ]; then \
  curl -fsSL -o llvm-project.tar.xz https://github.com/llvm/llvm-project/releases/download/llvmorg-${RVER}/llvm-project-${RVER}.src.tar.xz; \
  tar -xf llvm-project.tar.xz; \
  fi; \
  cmake -S llvm-project-${RVER}.src/runtimes -B /tmp/llvm-musl-build -G Ninja \
  -DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx" \
  -DLLVM_TARGETS_TO_BUILD="X86" \
  -DLLVM_RUNTIME_TARGETS="${TARGET_TRIPLE}" \
  -DCMAKE_INSTALL_PREFIX=${SYSROOT} \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DCMAKE_C_COMPILER=${CC} \
  -DCMAKE_CXX_COMPILER=${CXX} \
  -DCMAKE_C_COMPILER_TARGET=${TARGET_TRIPLE} \
  -DCMAKE_CXX_COMPILER_TARGET=${TARGET_TRIPLE} \
  -DCMAKE_ASM_COMPILER=${CC} \
  -DCMAKE_SYSROOT=${SYSROOT} \
  -DLLVM_USE_LINKER=lld \
  -DCMAKE_C_FLAGS="--target=${TARGET_TRIPLE} --sysroot=${SYSROOT} -idirafter /usr/include -idirafter /usr/include/x86_64-linux-gnu" \
  -DCMAKE_CXX_FLAGS="--target=${TARGET_TRIPLE} --sysroot=${SYSROOT} -idirafter /usr/include -idirafter /usr/include/x86_64-linux-gnu" \
  -DCMAKE_EXE_LINKER_FLAGS="--target=${TARGET_TRIPLE} --sysroot=${SYSROOT} -fuse-ld=lld -rtlib=compiler-rt" \
  -DCMAKE_SHARED_LINKER_FLAGS="--target=${TARGET_TRIPLE} --sysroot=${SYSROOT} -fuse-ld=lld -rtlib=compiler-rt" \
  -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_DOCS=OFF \
  -DLIBUNWIND_ENABLE_SHARED=OFF -DLIBUNWIND_ENABLE_STATIC=ON \
  -DLIBUNWIND_ENABLE_TESTS=OFF -DLIBUNWIND_ENABLE_EXAMPLES=OFF -DLIBUNWIND_ENABLE_DOCS=OFF \
  -DLIBCXXABI_ENABLE_SHARED=OFF -DLIBCXXABI_ENABLE_STATIC=ON \
  -DLIBCXXABI_USE_COMPILER_RT=ON \
  -DLIBCXXABI_ENABLE_TESTS=OFF -DLIBCXXABI_ENABLE_DOCS=OFF \
  -DLIBCXX_ENABLE_SHARED=OFF -DLIBCXX_ENABLE_STATIC=ON \
  -DLIBCXX_ENABLE_TESTS=OFF -DLIBCXX_ENABLE_EXAMPLES=OFF -DLIBCXX_ENABLE_DOCS=OFF \
  -DLIBCXX_USE_COMPILER_RT=ON \
  -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXX_HAS_MUSL_LIBC=ON \
  -DLIBCXX_INCLUDE_BENCHMARKS=OFF; \
  cmake --build /tmp/llvm-musl-build --target install -j"$(nproc)"; \
  rm -rf /tmp/llvm-project* /tmp/llvm-musl-build

WORKDIR /opt/src
COPY verify.cpp /opt/src/verify.cpp
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
