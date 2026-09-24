# Common Tools Interface

CTI provides a C API for launching and managing HPC applications and tool daemons across workload managers and compute environments.

This project exposes a frontend library for login-node orchestration and a backend library for tool daemons running on compute nodes. It is designed to abstract workload-manager differences while enabling tool deployment, session management, file staging, and runtime coordination.

## Summary

The Common Tools Interface (CTI) is an infrastructure framework for tool developers to launch, interact with, and run tool daemons alongside applications on HPC systems. CTI provides interfaces for application launch, registration, runtime inspection, file staging, and tool-daemon bootstrap. It abstracts workload-manager-specific details such as job launch, signal propagation, file transfer, and MPIR-aware placement so tool code can work across different environments.

## Documentation

- Detailed technical overview and API reference: [doc/overview.md](doc/overview.md)
- API headers: [include/common_tools_fe.h](include/common_tools_fe.h), [include/common_tools_be.h](include/common_tools_be.h), [include/common_tools_shared.h](include/common_tools_shared.h)
- Build examples: [open.sh](open.sh), [hpe/runBuild.sh](hpe/runBuild.sh)

## Features

- Launch and register applications under CTI control
- Hold applications at startup barriers for tooling setup
- Query workload-manager and application metadata
- Stage binaries, libraries, and files into per-session compute-node locations
- Launch tool daemons with managed environment setup
- Expose a backend API for node-local runtime information from tool daemons

## Supported libraries

| Library | Header | pkg-config |
| --- | --- | --- |
| `libcommontools_fe.so` | `common_tools_fe.h` | `common_tools_fe.pc` |
| `libcommontools_be.so` | `common_tools_be.h` | `common_tools_be.pc` |

## System requirements

CTI typically requires:

- A C and C++ toolchain
- Meson and a build environment
- `libarchive`
- `libssh2`
- OpenSSL
- Boost
- Threads support
- Dyninst / `symtabAPI` / `pcontrol` available to the build

On systems with a Cray Dyninst package, `cray-dyninst.pc` may satisfy the dependency. Otherwise the build falls back to the system Dyninst library location under `/usr/lib64/dyninst`.

## Building

From the project root:

```bash
meson setup build
meson compile -C build
meson install -C build
```

A typical configured build may include explicit installation paths and support directories, for example:

```bash
meson setup build \
  -Dprefix=/opt/cti \
  -Dlibdir=lib/cti \
  -Dflux-dir=/path/to/flux/headers \
  -Dpals-dir=/path/to/pals/headers
```

## Quick start

The usual flow is:

1. Detect or select the current workload manager.
2. Launch or register an application with CTI.
3. Create a session and manifest for dependencies.
4. Stage required binaries and libraries.
5. Launch tool daemons on the application nodes.
6. Use the backend library inside those daemons for node-local runtime data.

## Project status

CTI is an HPC tooling library intended for use with tool daemons and launcher integration. For the detailed behavior, API semantics, and backend/frontend interfaces, see [doc/overview.md](doc/overview.md).

## License

See [COPYING](COPYING).
