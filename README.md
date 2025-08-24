## musl + clang-20 Docker image (Alpine 3.22)

Alpine-based image that uses system musl and Clang 20. It builds and installs LLVM libc++ stack (libunwind, libc++abi, libc++) into `/usr` and makes libc++ the default for clang via `/etc/clang/clang.cfg`. The entrypoint compiles, runs, and verifies a small C++20 program using `std::format`, then checks the binary is fully static.

### What it includes
- Alpine 3.22 base (system musl)
- clang 20, lld
- LLVM libc++ stack 20.1.x built from source into `/usr` (both static libraries available)
- Defaults set in `/etc/clang/clang.cfg`: `-stdlib=libc++`, `-unwindlib=libunwind`, `-rtlib=compiler-rt`, `-fuse-ld=lld`

### Build
- Build the image from the repo root and tag it `musl-clang:alpine`.

### Run (auto-verification)
- Running the container compiles and executes the verification program and ensures the resulting binary is statically linked.
- Expected output: `Verification OK: Hello from musl+clang with C++20`.

### Notes
- Static-link check accepts musl ldd messages like "statically linked", "not a dynamic executable", or "Not a valid dynamic program".
- To change LLVM runtimes version, adjust `ARG LLVM_RUNTIMES_VERSION` in `Dockerfile`.
