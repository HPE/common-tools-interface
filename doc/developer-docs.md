# CTI Developer Handoff

## 1. Product overview

CTI lets HPC tools launch applications, attach to running applications, stage binaries and libraries, start tool daemons on compute nodes, and inspect rank placement without embedding workload-manager-specific code in each tool. CTI backs Cray PE tools such as GDB4hpc, ATP, STAT, and Valgrind4hpc.

The public interface is split across two shared libraries:

- **Frontend/login node**
  - Library: `libcommontools_fe.so`
  - Public header: `include/common_tools_fe.h`
  - `pkg-config` file: `common_tools_fe.pc`
  - Responsibility: launch or attach to applications, query placement, create sessions and manifests, stage files, and start tool daemons.
- **Backend/compute node**
  - Library: `libcommontools_be.so`
  - Public header: `include/common_tools_be.h`
  - `pkg-config` file: `common_tools_be.pc`
  - Responsibility: discover local application PIDs and ranks, identify the active workload manager, and locate files staged for a tool daemon.

`include/common_tools_shared.h` contains types and environment-variable names shared by both sides.

### Supported workload managers

CTI has frontend and backend implementations for:

- Slurm
- PALS
- ALPS
- Flux
- generic SSH with an MPIR-compliant launcher
- localhost, primarily for local operation and tests

Automatic workload-manager (WLM) detection is the default. `CTI_WLM_IMPL` overrides detection when system configuration is ambiguous.

### Terminology

- **CTI**
  - Common Tools Interface.
- **FE / frontend**
  - The login-node side of CTI and `libcommontools_fe`.
- **BE / backend**
  - The compute-node side of CTI and `libcommontools_be`.
- **WLM**
  - Workload manager, such as Slurm, PALS, ALPS, or Flux.
- **PE**
  - Processing element; an application rank.
- **MPIR**
  - Debugger/launcher interface used to discover and control launched processes.
- **Application**
  - A job launched by CTI or an existing job registered with CTI.
  - Represented by `cti_app_id_t`.
- **Session**
  - A staging and daemon-launch context associated with an application.
  - Represented by `cti_session_id_t`.
- **Manifest**
  - The binaries, libraries, and files to stage for a session.
  - Represented by `cti_manifest_id_t`.
- **Tool daemon**
  - A tool-owned process launched beside application ranks on compute nodes.

## 2. Source layout and design

### Repository map

- **`include/` - public C API headers**
  - `common_tools_fe.h` - frontend API.
  - `common_tools_be.h` - backend API.
  - `common_tools_shared.h` - shared types and environment variables.
- **`src/` - implementation**
  - **`frontend/` - login-node implementation**
    - `Frontend.{hpp,cpp}` - common `Frontend`, `App`, and `Session` object model.
    - `cti_fe_iface.{hpp,cpp}` - public C API implementation.
    - **`frontend_impl/` - WLM-specific frontend implementations**
      - `SLURM/`
      - `PALS/`
      - `ALPS/`
      - `Flux/`
      - `GenericSSH/`
      - `Localhost/`
    - `transfer/` - archive, manifest, and session staging logic.
    - `mpir_iface/` - Dyninst-backed MPIR process control.
    - `daemon/` - FE daemon, MPIR shim, stop helper, and preload helper.
    - `checksum/` - build-time BE daemon integrity checksum.
  - **`backend/` - compute-node implementation**
    - WLM-specific rank and PID discovery.
    - `daemon/` - daemon staged to compute nodes.
  - `SSHSession/` - SSH connection and transfer implementation.
  - `useful/` - logging, path, stack, and hostname helpers.
  - `utilities/` - diagnostics and support executables.
- **`tests/` - test suites and support**
  - `unit/` - Google Test and Google Mock unit tests.
  - `mock/` - mock frontend used by unit tests.
  - `test_support/` - gtest/gmock build and test helper libraries.
  - `function/` - Avocado-based WLM functional tests.
  - `pipeline/` - installed-product smoke-test resources.
- **Build, packaging, and documentation**
  - `pkgconfig/` - FE and BE `.pc` templates.
  - `doc/man/` - user and API man pages.
  - `doc/cpedocs/` - CPE documentation collection input.
  - `rpmbuild/` - RPM spec, modulefiles, and release data.
  - `external/` - build helpers and source dependencies.
  - `configure.ac` - Autoconf feature and dependency checks.
  - `Makefile.am` - top-level Automake graph.
  - `release_versioning` - product and libtool ABI versions.
  - `runBuild*.sh` - CI and build-VM workflow entry points.

### Runtime shape

- **Tool entry**
  - A tool on the login node calls `libcommontools_fe`.
- **Frontend dispatch**
  - The frontend detects the active WLM.
  - It selects the Slurm, PALS, ALPS, Flux, or generic SSH implementation.
  - It uses the Dyninst MPIR interface for process launch and control where required.
- **Staging and control**
  - Session and manifest code stages files to compute nodes.
  - The CTI frontend daemon coordinates with the version-matched backend daemon.
- **Compute-node execution**
  - The backend daemon starts the tool daemon.
  - The tool daemon uses `libcommontools_be` to read local rank, PID, and staged-file information.

The public API uses opaque integer handles (`cti_app_id_t`, `cti_session_id_t`, and `cti_manifest_id_t`). `src/frontend/cti_fe_iface.cpp` translates those C calls into the C++ object model in `src/frontend/Frontend.*`. WLM-specific `Frontend` and `App` subclasses implement launch, attach, signal, placement, and daemon-start behavior.

The frontend and backend are coupled by generated support files and versioned helper binaries. `configure.ac` gives the FE daemon, BE daemon, MPIR shim, Slurm stop helper, and first-subprocess helper names that include the CTI release version. The build also hashes the BE daemon through `src/frontend/checksum`; avoid post-link mutation or stripping of that binary. The RPM spec disables normal stripping for this reason.

### Frontend lifecycle

A typical tool follows this sequence:

1. Launch an application with `cti_launchApp` or `cti_launchAppBarrier`, or register an existing application with a WLM-specific attach call.
2. Keep the returned `cti_app_id_t` while the application is active.
3. Query hosts, ranks, binaries, or WLM-specific data.
4. Create a session with `cti_createSession`.
5. Create a manifest and add binaries, libraries, or data files.
6. Stage the manifest and launch the tool daemon with `cti_execToolDaemon`.
7. Release a startup barrier if one was requested.
8. Destroy sessions and deregister the application.

The API contract and ownership rules live in `include/common_tools_fe.h`. `README.md` is a more compact API walkthrough.

### File staging

`src/frontend/transfer/` separates staging into three objects:

- `Session`: lifetime and destination context tied to an application.
- `Manifest`: the caller's requested binaries, libraries, and files.
- `Archive`: packaging used to transfer manifest content.

CTI creates a per-daemon root on the compute node. The backend API returns its `bin`, `lib`, file, and temporary subdirectories. Staged `bin` and `lib` paths are added to the tool daemon's `PATH` and `LD_LIBRARY_PATH` respectively.

### Workload-manager boundaries

Keep generic behavior in `src/frontend/Frontend.*`, `src/frontend/transfer/`, or the shared backend implementation. Put launcher syntax, attach identifiers, placement discovery, and remote execution details under the corresponding WLM directory.

When changing a WLM implementation, inspect both sides:

- frontend: `src/frontend/frontend_impl/<WLM>/`
- backend: the matching file in `src/backend/`
- backend daemon loader: `src/backend/daemon/`
- functional coverage: `tests/function/tests.py` and `tests/function/src/`
- user workarounds and identifiers: `doc/man/cti.1.md`

### Build graph

The top-level Automake order is:

- **Build order**
  1. `src/useful`
  2. `src/SSHSession`
  3. `src/backend` and `src/backend/daemon`
  4. `src/frontend` subcomponents and the frontend library
  5. `src/utilities`
  6. `tests/mock`
  7. `tests/unit`
  8. `doc/man`

`src/frontend/libcommontools_fe.la` links the shared utility, SSH, daemon interface, transfer, WLM implementation, MPIR, and checksum libraries. `src/backend/libcommontools_be.la` compiles the enabled backend implementations into the backend shared library.

## 3. Environment setup

### Supported development environments

If desired, use a provisioned RHEL or SLES build VM for incremental development. GitHub Actions uses the target-specific images declared in `container_def.yaml` for full package builds.

The current CI matrix covers:

- RHEL 8.10 x86-64
- RHEL 9.5 and 9.6 on x86-64 and AArch64
- SLES 15 SP6 and SP7 on x86-64 and AArch64

Do not treat an arbitrary Linux workstation as equivalent to a build VM. The build scripts depend on HPE package repositories, environment modules, `cray-dyninst`, and the helper functions in `external/cdst_build_library`.

### Access checklist

Ensure access is available for the following:

- access to the CTI repository and its internal Git submodules;
- read access to `arti.hpc.amslabs.hpecorp.net` for build images and packages;
- a supported RHEL or SLES build VM;
- access to an HPC system with a Slurm or PALS allocation for functional tests;
- GitHub Actions visibility for pull-request and branch builds;
- CAST Jira access for customer issues and CPE Jira access for internal issues

### Initialize the checkout

Several build and test dependencies are Git submodules. Initialize them before building:

```bash
git submodule update --init --recursive
```

Important submodules from `.gitmodules`:

- **`external/cdst_build_library`**
  - OS detection, dependency installation, module setup, and CI status handling.
- **`external/libssh2`**
  - Source built into the CTI installation by `runBuild.sh`.
- **`external/libarchive`**
  - Source built into the CTI installation by `runBuild.sh`.
- **`external/libalps_headers`**
  - ALPS, PALS, and Flux build-time headers.
- **`tests/test_support/googletest`**
  - Google Test and Google Mock sources.
- **`tests/function/cdst-test`**
  - Functional-test runner and support data.
- **`external/changelog`**
  - Release-note generation tooling.
- **`rpmbuild/SOURCES/set_default`**
  - Module default-management packaging support.

### Build dependencies

`runBuildPrep.sh` installs or provisions the supported dependencies on the build VM:

- Autoconf, Automake, Autoconf Archive, Libtool, M4, and Make;
- GCC/G++ with C++17 support;
- binutils and development headers;
- zlib and libarchive development packages;
- Environment Modules and Tcl;
- RPM build tools;
- Python 3 and pip;
- Cray PE common components;
- `cray-dyninst`, including Boost and the Dyninst libraries used for MPIR control.

The script supports yum/dnf- and zypper-based build targets. It is infrastructure setup, not a portable installer for unsupported distributions.

### Runtime environment

A normal product module sets at least:

- **`CTI_INSTALL_DIR`**
  - Source: `cray-cti` module.
  - Purpose: root containing `lib`, `libexec`, headers, and man pages.
- **`CTI_VERSION`**
  - Source: `cray-cti` module.
  - Purpose: loaded CTI release.
- **`CRAY_CTI_PREFIX`**
  - Source: `cray-cti` module.
  - Purpose: product prefix used by PE tooling.
- **`CRAY_LD_LIBRARY_PATH` or `LD_LIBRARY_PATH`**
  - Source: `cray-cti` module.
  - Purpose: selects the CTI shared libraries.
- **`PKG_CONFIG_PATH`**
  - Source: `cray-cti-devel` module.
  - Purpose: exposes `common_tools_fe.pc` and `common_tools_be.pc`.

Load the runtime module for functional tests and the development module when compiling consumers:

```bash
module load cray-cti
module load cray-cti-devel
```

## 4. How to build

### Build entry points

- **`runBuildPrep.sh`**
  - Provision packages, PE components, and Dyninst on a supported build target.
- **`runBuild.sh`**
  - Build bundled libssh2 and libarchive, configure CTI, compile it, and install it.
- **`runBuild.sh --nodeps`**
  - Reconfigure, rebuild, and install CTI without rebuilding bundled libssh2/libarchive.
  - Use it after a successful full build.
- **`runBuildUnitTest.sh`**
  - Run Automake's `make check` and print `tests/unit/test-suite.log` on failure.
- **`runBuildPackage.sh`**
  - Generate CPE docs and release notes, then build RPMs.
- **`runInstallTest.sh`**
  - Install the generated RPM, verify release notes, and exercise uninstall in CI.
- **`build.sh`**
  - Drive internal `dst-rpm` container builds for selected targets.

### First build on a provisioned build VM

Initialize submodules, prepare the VM if needed, then run the full build:

```bash
git submodule update --init --recursive
./runBuildPrep.sh
./runBuild.sh
```

`runBuildPrep.sh` expects the CI/build-VM environment, including a build number when it updates non-release version data. On an already provisioned developer VM, skip it and load the required Dyninst module before `runBuild.sh`.

`runBuild.sh` performs these operations:

1. Loads `cray-dyninst`.
2. Derives the install version from `release_versioning` and branch type.
3. Builds and installs `external/libssh2`.
4. Builds and installs `external/libarchive` with CTI's reduced feature set.
5. Runs `autoreconf -ifv`.
6. Runs `./configure --prefix=/opt/cray/pe/cti/<version>`.
7. Runs parallel `make` and `make install`.
8. Builds installed functional-test helpers through the top-level install hook.

The build VM must permit writes under `/opt/cray/pe/cti/<version>`.

### Incremental build

After the first full build, skip the unchanged bundled dependencies:

```bash
./runBuild.sh --nodeps
```

For a source-only rebuild after configuration, use Automake directly:

```bash
make
make install
```

Run `./runBuild.sh --nodeps` instead when changes affect `configure.ac`, a `Makefile.am`, generated headers, versioned helper names, or dependency flags.

### Configure-time variants

`configure.ac` defines these relevant switches:

- **`--enable-code-coverage`**
  - Adds the Autoconf Archive coverage flags and coverage make targets.
- **`--enable-alps=no`**
  - Omits ALPS frontend/backend sources and their header check.
  - ALPS is enabled by default.
- **`--enable-pals=no`**
  - Omits PALS frontend/backend sources and their header check.
  - PALS is enabled by default.
- **`--with-flux=no`**
  - Omits Flux support.
  - The default header location is `external/libalps_headers`.
- **`--with-cray-dyninst=<path>`**
  - Selects a Cray Dyninst installation.
- **`--with-dyninst=<path>`**
  - Selects a non-Cray Dyninst installation.
- **`--with-libarchive-pc=<file>`**
  - Supplies the exact libarchive `.pc` file.
- **`--with-libssh2-pc=<file>`**
  - Supplies the exact libssh2 `.pc` file.
- **`--with-boost=<path>`**
  - Supplies the Boost installation root.

The wrapper scripts are the supported default. Invoke `configure` directly only when developing a configure-time variant; reproduce all required Dyninst, Boost, libarchive, and libssh2 paths.

### Artifacts and install layout

The default prefix is `/opt/cray/pe/cti/<version>`:

- **`<CTI_INSTALL_DIR>/`**
  - `include/` - FE, BE, shared, and version headers.
  - **`lib/` - CTI, libssh2, libarchive, and helper libraries**
    - `pkgconfig/` - `common_tools_fe.pc` and `common_tools_be.pc`.
  - `libexec/` - versioned CTI daemons, shims, and diagnostics.
  - `share/man/` - `cti(1)` and `cti(3)`.

RPMs are created under `rpmbuild/RPMS/<architecture>/`. The CI post-build wrapper copies them into the target-specific `RPMS` delivery directory.

### Common build failures

- **`libssh2 submodule not checked out` or `libarchive submodule not checked out`**
  - Cause: incomplete checkout.
  - Fix: run `git submodule update --init --recursive`.
- **`module: command not found`**
  - Cause: the shell is not a provisioned RHEL/SLES build environment.
  - Fix: move to a build VM or use the CI build image; do not patch around the module dependency.
- **`Use --with-cray-dyninst or --with-dyninst`**
  - Cause: `cray-dyninst` is not loaded or its install variable is absent.
  - Fix: load the build VM's `cray-dyninst` module.
- **Missing `archive.h`, `libssh2.h`, Boost, `libsymtabAPI`, or `libpcontrol`**
  - Cause: dependency paths do not match the loaded Dyninst/CTI prefix.
  - Fix: re-run build preparation, then inspect `config.log` and the `.pc` paths printed by configure.
- **Missing `alps/alps.h`, `pals.h`, or `flux/core.h`**
  - Cause: `external/libalps_headers` is absent or the corresponding feature should be disabled.
  - Fix: initialize the submodule or pass the documented disable option.
- **Permission denied under `/opt/cray/pe/cti`**
  - Cause: the developer VM does not allow installation to the product prefix.
  - Fix: use the team build VM policy; do not change the product prefix for package validation.
- **Generated daemon checksum mismatch at runtime**
  - Cause: a versioned BE daemon was stripped or modified after link.
  - Fix: rebuild and install the unmodified artifact. The RPM spec intentionally disables stripping.

## 5. How to test

CTI has distinct test tiers. Unit tests run without an HPC allocation; functional tests exercise real launchers and compute nodes.

### Unit tests

Run the repository wrapper after a successful build:

```bash
./runBuildUnitTest.sh
```

The wrapper calls `make check`. Automake builds and runs two Google Test executables defined in `tests/unit/Makefile.am`:

- `unit_tests`: frontend API, backend API, archive, manifest, session, and utility behavior;
- `flux_api_parse_tests`: Flux API and response parsing.

Test support comes from:

- `tests/test_support/googletest/`: Google Test and Google Mock source submodule;
- `tests/test_support/`: locally built `libgtest.so`, `libgmock.so`, and helper libraries;
- `tests/mock/MockFrontend/`: mock WLM frontend used to isolate the public FE API.

On failure, inspect `tests/unit/test-suite.log`.

Add a unit test when behavior can be isolated from a real launcher, allocation, remote host, or WLM service. Keep WLM command construction and parser cases deterministic.

### Functional tests

Functional tests live in `tests/function/` and use Avocado through the `cdst-test` runner. Run them on an HPC system with a Slurm or PALS allocation, not on the build VM alone.

From the functional-test directory:

```bash
cd tests/function
git submodule update --init ./cdst-test
./test_tool.py
```

If an extracted test tree is owned by root, the runner supports copying it to a writable destination first:

```bash
./test_tool.py --cp <destination>
./test_tool.py
```

`tests/function/test_tool_config.yaml` supplies:

- build modules: `cray-cti-devel`;
- runtime module: `cray-cti`;
- required `CTI_INSTALL_DIR` and library path setup;
- launcher arguments for Slurm, ALPS, and Flux;
- allocation parameters and per-system parallelism.

`tests/function/tests.py` covers WLM detection, launch and barrier behavior, attach paths, sessions, manifests, file transfer, environment propagation, I/O redirection, daemon launch, MPMD behavior, signals, multithreading, and error cases. C and C++ test programs are under `tests/function/src/`.

Use an allocation sized for the configured launcher arguments. The default Slurm test launch requests four tasks across two nodes; system-specific sections in `test_tool_config.yaml` override allocation and parallelism.

### Installed product tests

- `tests/pipeline/` contains post-install smoke resources used by the DST pipeline. Its prebuilt checks link against the installed frontend library and exercise version/WLM entry points.
- `runInstallTest.sh` installs generated RPMs with yum or zypper, checks for release notes, and verifies uninstall cleanup in CI.

### Coverage

Configure with `--enable-code-coverage` to enable the Automake coverage targets. Helper scripts are under `tests/scripts/`:

- `create_local_gcov_report.sh`
- `create_sonar_gcov_report.sh`
- `install_sonar.sh`
- `sonar-scanner.properties.default`

Coverage is useful for unit-testable generic logic. It does not replace functional coverage of launcher, allocation, staging, or compute-node behavior.

### CI behavior

`.github/workflows/build_pipeline.yaml` runs on:

- pushes to `master`;
- pushes to `release/**`;
- pull requests;
- manual workflow dispatch, optionally limited to one target.

Each matrix job delegates to `hpcde/devops-shared-workflows/.github/workflows/full_workflow.yaml@main`. The repository-side stage scripts are:

- **Preparation**
  - `preBuild.sh` runs `runBuildPrep.sh`.
- **Build**
  - `rpmBuild.sh` runs `runBuild.sh`.
- **Unit tests**
  - `runBuildUnitTest.sh` runs the Automake test suite.
- **Packaging and install checks**
  - `postBuild.sh` runs `runBuildPackage.sh`, then `runInstallTest.sh`.

Use the GitHub Actions run for package-build results. Functional tests that need a real Slurm or PALS allocation remain a separate system-level check.

## 6. How to maintain and release

### Versioning

`release_versioning` owns two independent version schemes:

1. `common_tool_major.common_tool_minor.revision`: product/module release version.
2. `current:revision:age` values for each FE and BE shared library: libtool ABI versioning.

Apply the rules documented in that file:

- implementation-only binary change: increment the relevant libtool revision;
- backward-compatible API addition: increment product minor plus libtool current and age, and reset revision;
- removed or incompatible API: increment product major and libtool current, reset product minor and libtool age/revision.

Update FE and BE ABI values independently when only one public library changes. Review public declarations in `include/common_tools_fe.h`, `include/common_tools_be.h`, and `include/common_tools_shared.h` before deciding that a change is ABI-neutral.

### Release flow

1. Land release-ready changes on `master` with unit and required system-level testing complete.
2. Update `release_versioning`, release-note data under `rpmbuild/SOURCES/`, and `CHANGELOG.md` as required by the release.
3. Cut `release/X.Y` from `master`.
4. Let GitHub Actions build the full RHEL/SLES architecture matrix.
5. The pipeline builds RPMs, generates release notes, performs package install checks, and publishes package artifacts to `arti.hpc.amslabs.hpecorp.net`.
6. System administrators install the approved packages on target systems.

### Dependencies

Most non-system dependencies are pinned as submodule commits. Update the relevant submodule intentionally, build the complete target matrix, and exercise the affected test tier. High-risk updates include:

- Dyninst or Boost: MPIR control, linker flags, and C++ compatibility;
- libssh2: GenericSSH sessions and remote file transfer;
- libarchive: manifest packaging and extraction;
- ALPS/PALS/Flux headers: compile-time WLM API compatibility;
- Google Test: unit-test-only dependency;
- `cdst_build_library`: all supported build targets and release metadata behavior.

There is no dependency-update bot configured in this repository. Coordinate security-driven updates through the CTI product SMEs and the applicable HPE security process.

### Installing without root

Administrators normally install the RPM. For development on a system where root access is unavailable, extract the RPM and load it through a custom modulefile:

```bash
mkdir -p "$HOME/opt/cti-rpm"
cd "$HOME/opt/cti-rpm"
rpm2cpio /path/to/cray-cti-<version>.<arch>.rpm | cpio -idmv
```

Point the custom modulefile at the extracted `opt/cray/pe/cti/<version>` directory. Mirror the shipped templates in `rpmbuild/SOURCES/cray-cti.module.template` and `cray-cti-devel.module.template`. At minimum, set `CTI_VERSION`, `CTI_INSTALL_DIR`, and `CRAY_CTI_PREFIX`; add the installation's `lib` directory to `LD_LIBRARY_PATH`, its `share/man` directory to `MANPATH`, and its `lib/pkgconfig` directory to `PKG_CONFIG_PATH` for development.

## 7. How to triage

### First response

1. Record the CTI module version, system type, WLM, launcher command, attach identifier if applicable, and whether launch or attach failed.
2. Ask the tool to report `cti_error_str()` immediately after the failed CTI call; later calls can replace the stored error.
3. Reproduce with CTI debug logging enabled in a shared directory.
4. Separate frontend launch/control failure from backend daemon/staging failure.
5. Run the installed diagnostic utility when the failure involves launch, staging, or compute-node callbacks.
6. Escalate with logs, launcher arguments, allocation identifiers, and the smallest reproducer.

### Enable logs

```bash
export CTI_DEBUG=1
export CTI_LOG_DIR="$HOME/cti-logs"
mkdir -p "$CTI_LOG_DIR"
```

`CTI_LOG_DIR` must be visible from compute nodes. Without it, backend logs default to compute-node `/tmp` and are harder to collect. Debug mode captures frontend startup/attach activity and output from remote tool utilities.

### Diagnostic utility

The installed `cti_diagnostics` program launches a small target, creates a session, starts a backend diagnostic daemon, and checks the callback path to the frontend:

```bash
"$CTI_INSTALL_DIR/libexec/cti_diagnostics" <launcher-arguments>
```

Supply arguments appropriate for the active WLM. If it cannot locate the installation, load `cray-cti` or correct `CTI_INSTALL_DIR`.

### Failure guide

- **`CTI_INSTALL_DIR` is unset or helper binaries are missing**
  - Check: loaded module and modulefile prefix.
- **Wrong WLM or launcher selected**
  - Check: compare `cti_current_wlm()` with system configuration.
  - Use `CTI_WLM_IMPL` or `CTI_LAUNCHER_NAME` only as a temporary check override.
- **Remote tool daemon cannot connect to frontend**
  - Check: address printed by diagnostics and compute-node reachability.
- **Logs appear only on compute nodes**
  - Check: whether `CTI_DEBUG` is set while `CTI_LOG_DIR` is absent or not shared.
  - Resolution: point `CTI_LOG_DIR` to a cross-mounted directory.
- **Staged helper fails with permission denied**
  - Check: whether the compute-node temporary filesystem exists and is executable.
  - Resolution: set `CTI_BACKEND_TMPDIR` to an executable filesystem available on compute nodes.
- **Generic SSH hangs or requests a password**
  - Check: key-based access and known-hosts configuration.
  - Resolution: configure passwordless SSH or set the documented `CTI_SSH_*` paths.
- **PALS attach by APID fails outside the allocation**
  - Check: execution-host context.
  - Resolution: use a PBS job ID, `pbs_job_id:pals_apid`, or set `CTI_PALS_EXEC_HOST`.
- **Single-node PALS job cannot be attached**
  - Check: whether the PALS local-launch optimization hides the job from the service.
  - Resolution: launch with `PALS_LOCAL_LAUNCH=0`.
- **Flux library compatibility check fails**
  - Check: whether runtime Flux differs from the API expected at build time.
  - Resolution: verify `FLUX_INSTALL_DIR` and `LIBFLUX_PATH`; use `CTI_FLUX_DEBUG` only while diagnosing compatibility.

`doc/man/cti.1.md` is the primary documentation for supported environment variables and WLM-specific workarounds. Keep that file updated when adding or removing a workaround.

### Attach identifiers

Use the identifier format expected by the WLM:

- **Slurm**
  - `<jobid>.<stepid>`
- **PALS**
  - `<pals_apid>`, `<pbs_job_id>`, or `<pbs_job_id>:<pals_apid>`, depending on execution context.
- **Flux**
  - f58-style or numeric Flux job ID.
- **ALPS**
  - `aprun` application ID.
- **Generic SSH**
  - PID of the MPIR-compliant launcher.

### Escalation

- Customer reports usually arrive by email or Jira and should be tracked in the CAST Jira project.
- Internal reports may arrive through Slack or email and should be tracked in the CPE Jira project.
- Include debug logs, CTI version, WLM version, launch/attach arguments, allocation details, and a minimal reproducer.

## 8. SME directory

- **Andrew D'Angelo**
  - Contact: `andrew.dangelo@hpe.com`
- **John Leroy Vogt**
  - Contact: `john.leroy.vogt@hpe.com`


## 9. Reference links

### In-repository references

- **`README.md`**
  - Product synopsis and frontend/backend API walkthrough.
- **`include/common_tools_fe.h`**
  - Authoritative frontend API, arguments, return values, and ownership rules.
- **`include/common_tools_be.h`**
  - Authoritative backend API and staged-directory semantics.
- **`include/common_tools_shared.h`**
  - Shared WLM types and supported environment-variable definitions.
- **`doc/man/cti.1.md`**
  - User-facing launch, attach, environment, and WLM workaround guide.
- **`doc/man/cti.3.md`**
  - CTI API man page source.
- **`configure.ac`**
  - Build feature switches, dependency checks, generated files, and versioned helpers.
- **`release_versioning`**
  - Product and libtool ABI version rules.
- **`.github/workflows/build_pipeline.yaml`**
  - Supported CI target matrix and trigger rules.
- **`container_def.yaml`**
  - Build-target names and Artifactory image locations.
- **`rpmbuild/SPECS/cray-cti.spec`**
  - Package layout, dependencies, and artifact handling.
- **`tests/function/test_tool_config.yaml`**
  - Functional-test modules, launcher arguments, allocations, and system overrides.
