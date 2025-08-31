## Ubuntu 16.04 base with LLVM 20, CMake 3.31, and libc++ runtimes
FROM ubuntu:16.04

ARG LLVM_VERSION=20.1.0
ARG CMAKE_VERSION=3.31.0
ENV TZ=Etc/UTC \
    DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/cmake-${CMAKE_VERSION}-linux-x86_64/bin:/usr/local/llvm-20/bin:$PATH

# Point apt to old-releases, install prerequisites, newer GCC for building LLVM, and Ninja
RUN set -eux; \
  sed -i -e 's|archive.ubuntu.com|old-releases.ubuntu.com|g' -e 's|security.ubuntu.com|old-releases.ubuntu.com|g' /etc/apt/sources.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    ca-certificates tzdata curl wget git xz-utils \
    software-properties-common gnupg2 \
    build-essential python3 pkg-config \
    ninja-build zlib1g-dev libxml2-dev libedit-dev libffi-dev libbsd-dev libncurses5-dev linux-libc-dev; \
  add-apt-repository -y ppa:ubuntu-toolchain-r/test; \
  apt-get update; \
  apt-get install -y --no-install-recommends gcc-10 g++-10; \
  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100 \
                      --install /usr/bin/g++ g++ /usr/bin/g++-10 100; \
  rm -rf /var/lib/apt/lists/*

# Install CMake 3.31
RUN set -eux; \
  cd /usr/local; \
  curl -fsSL -o cmake.tar.gz https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz; \
  tar -xzf cmake.tar.gz; \
  rm -f cmake.tar.gz; \
  cmake --version

# Build and install LLVM/Clang/LLD ${LLVM_VERSION}
WORKDIR /tmp
RUN set -eux; \
  curl -fsSL -o llvm-project.tar.xz https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/llvm-project-${LLVM_VERSION}.src.tar.xz; \
  tar -xf llvm-project.tar.xz; \
  cmake -S llvm-project-${LLVM_VERSION}.src/llvm -B /tmp/llvm-build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=g++ \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_ENABLE_TERMINFO=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/local/llvm-20; \
  cmake --build /tmp/llvm-build -j"$(nproc)"; \
  cmake --build /tmp/llvm-build --target install; \
  rm -rf /tmp/llvm-build

# Build and install libc++ stack (compiler-rt, libunwind, libc++abi, libc++)
RUN set -eux; \
  cmake -S llvm-project-${LLVM_VERSION}.src/runtimes -B /tmp/llvm-rt-build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=/usr/local/llvm-20/bin/clang \
    -DCMAKE_CXX_COMPILER=/usr/local/llvm-20/bin/clang++ \
    -DLLVM_ENABLE_RUNTIMES="compiler-rt;libunwind;libcxxabi;libcxx" \
    -DLIBCXXABI_HAS_CXA_THREAD_ATEXIT_IMPL=OFF \
    -DLIBCXX_USE_COMPILER_RT=ON \
    -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
    -DLIBUNWIND_ENABLE_SHARED=ON -DLIBUNWIND_ENABLE_STATIC=ON \
    -DLIBCXXABI_ENABLE_SHARED=ON -DLIBCXXABI_ENABLE_STATIC=ON \
    -DLIBCXX_ENABLE_SHARED=ON -DLIBCXX_ENABLE_STATIC=ON \
    -DCMAKE_INSTALL_PREFIX=/usr/local/llvm-20; \
  cmake --build /tmp/llvm-rt-build -j"$(nproc)"; \
  cmake --build /tmp/llvm-rt-build --target install; \
  rm -rf /tmp/llvm-rt-build /tmp/llvm-project*

# Configure clang defaults to prefer libc++ and lld and point to installed headers/libs
RUN set -eux; \
  mkdir -p /etc/clang; \
  printf "-stdlib=libc++\n-unwindlib=libunwind\n-rtlib=compiler-rt\n-fuse-ld=lld\n-isystem /usr/local/llvm-20/include/c++/v1\n-L/usr/local/llvm-20/lib\n" > /etc/clang/clang.cfg; \
  echo "/usr/local/llvm-20/lib" > /etc/ld.so.conf.d/llvm20.conf; \
  ldconfig

# Add verification source and entrypoint (optional smoke test)
WORKDIR /opt/src
COPY verify.cpp /opt/src/verify.cpp
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
