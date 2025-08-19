# musl + clang-20 Docker image (Ubuntu 24.04)

This image builds a musl-based C/C++ toolchain with Clang 20 and statically builds libc++/libc++abi/libunwind (plus compiler-rt builtins) targeting musl. The container entrypoint compiles, runs, and verifies a small C++20 program using `std::format`, and also checks the binary is statically linked.

## What it includes
- Ubuntu 24.04 base
- clang-20, lld-20
- musl 1.2.5 installed to `/opt/musl`
- libc++/libc++abi/libunwind/`compiler-rt` (LLVM 20.1.x) for musl, static, installed into the musl sysroot

## Build
```pwsh
# From this directory
docker build -t musl-clang:20 .
```

## Run (verification happens automatically)
```pwsh
docker run --rm musl-clang:20
```
You should see:
```
Verification OK: Hello from musl+clang with C++20
```

## Notes
- The entrypoint additionally verifies the produced binary is statically linked (using `ldd`).
- The image builds static libraries to enable fully static linking of the test.
- `TARGET_TRIPLE` defaults to `x86_64-unknown-linux-musl`.
- Musl sysroot: `/opt/musl`
- You can mount your project and compile with flags similar to the entrypoint:
  - `--target=$TARGET_TRIPLE --sysroot=/opt/musl -static -stdlib=libc++ -lc++abi -lunwind -rtlib=compiler-rt -I/opt/musl/include/c++/v1 -L/opt/musl/lib`

### Switching versions (optional)
- To try a different LLVM version, edit the Dockerfile `ARG LLVM_VERSION` and `ARG LLVM_RUNTIMES_VERSION` accordingly and adjust the linker path in `entrypoint.sh` (e.g., `ld.lld-19`). Tag your image appropriately (e.g., `musl-clang:19`).
