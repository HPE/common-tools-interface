project('common_tool_interface', 'c', 'cpp',
  version: run_command(
    'bash',
    '-c', 'source '
    + meson.current_source_dir()
    + '/release_versioning && echo "$common_tool_major.$common_tool_minor.$revision.$build_number"',
    check: true,
  ).stdout().strip(),
  meson_version: '>=0.58.0',
  default_options: [
    'cpp_std=c++17',
    'warning_level=1', # equivalent to -Wall -Wextra
    'werror=false',
  ],
)

cc = meson.get_compiler('c')
cxx = meson.get_compiler('cpp')
prefix = get_option('prefix')

add_project_link_arguments('-Wl,--as-needed', language: ['c', 'cpp'])

# Get all of the values defined in release_versioning, there are more in CTI
# because it also define libtools style version numbers

version_vals_str = run_command(
    'bash',
    '-c', 'source '
    + meson.current_source_dir()
    + '/release_versioning && echo "$common_tool_major.$common_tool_minor.$revision.$be_current.$be_age.$be_revision.$fe_current.$fe_age.$fe_revision.$build_number"',
    check: true,
  ).stdout().strip()

version_vals = version_vals_str.split('.')

common_tool_major = version_vals[0]
common_tool_minor = version_vals[1]
revision          = version_vals[2]
be_current        = version_vals[3]
be_age            = version_vals[4]
be_revision       = version_vals[5]
fe_current        = version_vals[6]
fe_age            = version_vals[7]
fe_revision       = version_vals[8]
build_number      = version_vals[9]

release_version = meson.project_version()

commontool_be_version = ':'.join([be_current,be_revision,be_age])
commontool_fe_version = ':'.join([fe_current,fe_revision,fe_age])

cti_be_version = '.'.join(['@0@'.format(be_current.to_int()-be_age.to_int()),be_age,be_revision])
cti_fe_version = '.'.join(['@0@'.format(fe_current.to_int()-fe_age.to_int()),fe_age,fe_revision])

inc_src = include_directories('src')
inc_public = include_directories('include')
inc_root = include_directories('.')

libdir = get_option('libdir')
if libdir.endswith('lib')
  libexecdir = libdir + 'exec'
  rel_rpath = '$ORIGIN/..' / libdir
else  
  libexecdir = libdir.replace('lib/', 'libexec/')
  rel_rpath = '$ORIGIN/../..' / libdir
endif  

enable_alps = false
pals_dir = get_option('pals-dir')
enable_pals = pals_dir != ''
if enable_pals
   inc_pals = include_directories(pals_dir)
endif   

flux_dir = get_option('flux-dir')
enable_flux = flux_dir != ''
if enable_flux
   inc_flux = include_directories(flux_dir)
endif   

cmake = import('cmake')

archive_dep = dependency(
  'libarchive',
  fallback : ['libarchive', 'archive_dep'],
  required: true)

ssh2_dep = dependency('libssh2', required: true)
openssl_dep = dependency('openssl', required: true)
boost_dep = dependency('boost', required: true)
threads_dep = dependency('threads')
dl_dep = cc.find_library('dl', required: false)
rt_dep = cc.find_library('rt', required: false)

cray_dyninst_dep = dependency('cray-dyninst', required: false)
if cray_dyninst_dep.found()
  # cray-dyninst.pc doesn't list the actual libraries to link, so find them explicitly
  dyninst_libdir = cray_dyninst_dep.get_variable(pkgconfig: 'libdir', default_value: '')
  symtabAPI_lib = cxx.find_library('symtabAPI', dirs: dyninst_libdir, required: true)
  pcontrol_lib = cxx.find_library('pcontrol', dirs: dyninst_libdir, required: true)

  dyninst_dep = declare_dependency(
    dependencies: [ cray_dyninst_dep, symtabAPI_lib, pcontrol_lib ],
  )
else
  symtabAPI_lib = cxx.find_library(
     'symtabAPI',
     dirs: '/usr/lib64/dyninst',
     required: true,
  )
  pcontrol_lib = cxx.find_library(
     'pcontrol',
     dirs: '/usr/lib64/dyninst',
     required: true
  )

  dyninst_dep = declare_dependency(
    include_directories: ['/usr/include/dyninst'],
    dependencies: [ symtabAPI_lib, pcontrol_lib ],
  )
endif

config = configuration_data()
config.set_quoted('CTI_RELEASE_VERSION', release_version)
config.set_quoted('CTI_BE_DAEMON_BINARY', 'cti_be_daemon' + release_version)
config.set_quoted('CTI_BE_VERSION', cti_be_version)
config.set_quoted('CTI_FE_DAEMON_BINARY', 'cti_fe_daemon' + release_version)
config.set_quoted('CTI_FE_VERSION', cti_fe_version)
config.set_quoted('CTI_FIRST_SUBPROCESS_BINARY', 'cti_first_subprocess' + release_version)
config.set_quoted('CTI_MPIR_SHIM_BINARY', 'mpir_shim' + release_version)
config.set_quoted('CTI_SLURM_STOP_BINARY' , 'cti_slurm_stop' + release_version)
config.set_quoted('CTI_STOP_LIBRARY', 'libctistop.so')

config.set('HAVE_ALPS', enable_alps ? 1 : false)
config.set('HAVE_PALS', enable_pals ? 1 : false)
config.set('HAVE_FLUX', enable_flux ? 1 : false)
configure_file(
  output: 'config.h',
  configuration: config
)

version_config = configuration_data()
version_config.set_quoted('CTI_PACKAGE_VERSION', release_version)
version_config.set('CTI_PACKAGE_MAJOR', common_tool_major)
version_config.set('CTI_PACKAGE_MINOR', common_tool_minor)
version_config.set('CTI_PACKAGE_REVISION', revision)
version_config.set('CTI_PACKAGE_BUILD_NUMBER', build_number)
version_config.set_quoted('CTI_BE_VERSION', cti_be_version)
version_config.set('CTI_BE_CURRENT', be_current)
version_config.set('CTI_BE_AGE', be_age)
version_config.set('CTI_BE_REVISION', be_revision)
version_config.set_quoted('CTI_FE_VERSION', cti_fe_version)
version_config.set('CTI_FE_CURRENT', fe_current)
version_config.set('CTI_FE_AGE', fe_age)
version_config.set('CTI_FE_REVISION', fe_revision)

common_tools_version_h = configure_file(input: 'include/common_tools_version.h.in',
  output: 'common_tools_version.h', configuration: version_config)

ld_val = static_library('ld_val',
  'src/useful/ld_val/ld_val.c',
  include_directories: [inc_src, inc_public], 
  install: false
)

audit = shared_library('ctiaudit',
  'src/useful/ld_val/audit.c',
  include_directories: inc_src,
  install: true)

useful = static_library('useful',
  ['src/useful/cti_log.c', 'src/useful/cti_path.c', 'src/useful/cti_stack.c'],
  include_directories: [inc_src, inc_public],
  link_with: ld_val, install: false)

ssh_session = static_library('sshsession', 'src/SSHSession/SSHSession.cpp',
  include_directories: [inc_src, inc_public],
  dependencies: ssh2_dep, install: false)

transfer = static_library('transfer',
  ['src/frontend/transfer/Archive.cpp', 'src/frontend/transfer/Manifest.cpp',
   'src/frontend/transfer/Session.cpp'],
  include_directories: [inc_src, inc_public],
  dependencies: archive_dep, install: false)

mpir_iface = static_library('mpir_iface',
  ['src/frontend/mpir_iface/MPIRInstance.cpp', 'src/frontend/mpir_iface/Inferior.cpp'],
  include_directories: [inc_src, inc_public],
  dependencies: dyninst_dep,
  install: false)

slurm = static_library('slurm', 'src/frontend/frontend_impl/SLURM/Frontend.cpp',
  include_directories: [inc_src, inc_public, 'src/frontend', 'src/frontend/frontend_impl'],
  dependencies: [ssh2_dep], install: false)
generic_ssh = static_library('genericssh', 'src/frontend/frontend_impl/GenericSSH/Frontend.cpp',
  include_directories: [inc_src, inc_public, 'src/frontend', 'src/frontend/frontend_impl'],
  dependencies: [ssh2_dep], install: false)
localhost = static_library('localhost', 'src/frontend/frontend_impl/Localhost/Frontend.cpp',
  include_directories: [inc_src, inc_public, 'src/frontend', 'src/frontend/frontend_impl'],
  dependencies: [ssh2_dep], install: false)


frontend_impl_libs = [slurm, generic_ssh, localhost]
frontend_impl_sources = []
if enable_pals
  pals = static_library('pals', 'src/frontend/frontend_impl/PALS/Frontend.cpp',
    include_directories: [inc_src, inc_public, 'src/frontend', 'src/frontend/frontend_impl', inc_pals],
    dependencies: [threads_dep, dyninst_dep], install: false)
  frontend_impl_libs += pals
  install_data('src/frontend/frontend_impl/PALS/cti_pmix_util.c', install_dir: prefix / 'pals')
endif
if enable_flux
  flux_header_generator = find_program('src/frontend/frontend_impl/Flux/generate_hdrs.sh')
  flux_headers = custom_target('flux_headers',
    input: ['src/frontend/frontend_impl/Flux/generate_libflux.py',
	    'src/frontend/frontend_impl/Flux/LibFlux.hpp.in'],
    output: ['LibFlux.hpp', 'LibFluxCompat.hpp'],
    command: [flux_header_generator ],
    build_by_default: true,
  )
  flux = static_library('flux',
    [flux_headers, 'src/frontend/frontend_impl/Flux/Frontend.cpp'],
    include_directories: [inc_src, inc_public, 'src/frontend', 'src/frontend/frontend_impl', inc_flux],
    dependencies: [archive_dep, boost_dep, threads_dep], install: false)
  frontend_impl_libs += flux
endif
frontend_impl = static_library('frontend_impl', frontend_impl_sources,
  link_whole: frontend_impl_libs, install: false)

fe_daemon_iface = static_library('fe_daemon_iface', 'src/frontend/daemon/cti_fe_daemon_iface.cpp',
  include_directories: [inc_src, inc_public], install: false)


be_sources = ['src/backend/cti_be.c', 'src/backend/slurm_be.c',
  'src/backend/pmi_attribs_parser.c', 'src/backend/generic_ssh_be.c',
  'src/backend/localhost_be.c']

be_incs = [inc_src, inc_public]

if enable_alps
  be_sources += 'src/backend/alps_be.c'
endif

if enable_pals
  be_sources += 'src/backend/pals_be.c'
  be_incs += inc_pals
endif

if enable_flux
  be_sources += 'src/backend/flux_be.c'
  be_incs += inc_flux
endif

be_lib = shared_library('commontools_be', be_sources,
  include_directories: be_incs,
  dependencies: [dl_dep],
  soversion: '2',
  version: '2.5.0',
  install: true,
)

stop_lib = shared_library('ctistop',
  'src/frontend/daemon/libctistop.c',
  install: true,
)

preload_lib = shared_library('ctipreloadpals',
  'src/frontend/daemon/libctipreloadpals.c',
  dependencies: [dl_dep],
  install: true,
)

be_daemon_sources = ['src/backend/daemon/cti_be_daemon.c',
  'src/backend/daemon/slurm_dl.c', 'src/backend/daemon/generic_ssh_dl.c',
  'src/backend/daemon/localhost_dl.c']
if enable_alps
  be_daemon_sources += 'src/backend/daemon/alps_dl.c'
endif
if enable_pals
  be_daemon_sources += 'src/backend/daemon/pals_dl.c'
endif
if enable_flux
  be_daemon_sources += 'src/backend/daemon/flux_dl.c'
endif

cti_be_daemon = executable('cti_be_daemon' + release_version,
  be_daemon_sources,
  include_directories: [inc_src, inc_public, 'src/useful', be_incs],
  dependencies: [archive_dep, dl_dep], link_with: useful,
  install: true,
  install_dir: libexecdir)

checksum_header = custom_target('checksums.h',
  input: [ cti_be_daemon, 'src/frontend/checksum/checksums.h.in'],
  output: 'checksums.h',
  command: [find_program('src/frontend/checksum/generate_hdr.sh'), cti_be_daemon, '@OUTPUT@'])

checksum = static_library('checksum', ['src/frontend/checksum/libchecksum.cpp', checksum_header],
  include_directories: inc_src, install: false)

fe_lib = shared_library(
  'commontools_fe',
  ['src/frontend/Frontend.cpp', 'src/frontend/cti_fe_iface.cpp', checksum_header],
  include_directories: [inc_src, inc_public, 'src/frontend', 'src/frontend/frontend_impl'],
  dependencies: [archive_dep, ssh2_dep, openssl_dep, dyninst_dep, dl_dep, rt_dep, threads_dep],
  link_with: [useful, ssh_session, transfer, frontend_impl, mpir_iface, fe_daemon_iface, checksum],
  soversion: '2', version: '2.5.0',
  install_rpath: '$ORIGIN/../dyninst',
  install: true,
)

common_tools_fe_dep = declare_dependency(
  link_with: fe_lib,
  include_directories: [inc_public, inc_root],
  variables: {
    'libdir': prefix / get_option('libdir'),
  }
)
meson.override_dependency('common_tools_fe', common_tools_fe_dep)

common_tools_be_dep = declare_dependency(
  link_with: be_lib,
  include_directories: [inc_public, inc_root],
)
meson.override_dependency('common_tools_be', common_tools_be_dep)

executable('cti_fe_daemon' + release_version,
  'src/frontend/daemon/cti_fe_daemon.cpp',
  include_directories: [inc_src, inc_public],
  dependencies: [dyninst_dep, threads_dep],
  link_with: [fe_daemon_iface, mpir_iface, useful],
  install: true,
  install_dir: libexecdir)

executable('mpir_shim' + release_version,
  'src/frontend/daemon/mpir_shim.cpp',
  include_directories: [inc_src, inc_public],
  dependencies: [dyninst_dep],
  link_with: mpir_iface,
  install: true,
  install_dir: libexecdir)

executable('cti_slurm_stop' + release_version,
  'src/frontend/daemon/cti_slurm_stop.c',
  install: true,
  install_dir: libexecdir)

executable('cti_diagnostics',
  'src/utilities/cti_diagnostics.cpp',
  include_directories: [inc_src, inc_public],
  dependencies: [dyninst_dep, threads_dep],
  link_with: fe_lib,
  install_rpath: rel_rpath,
  install: true,
  install_dir: libexecdir)

executable('cti_diagnostics_backend', 'src/utilities/cti_diagnostics_backend.c',
  include_directories: [inc_src, inc_public], link_with: be_lib,
  install_rpath: rel_rpath,
  install: true, install_dir: libexecdir)
executable('cti_diagnostics_target', 'src/utilities/cti_diagnostics_target.c',
  install_rpath: rel_rpath,
  install: true, install_dir: libexecdir)
executable('cti_first_subprocess' + release_version, 'src/utilities/cti_first_subprocess.c',
  install: true, install_dir: libexecdir)
executable('cti_send_signal_backend', 'src/utilities/cti_send_signal_backend.c',
  include_directories: inc_public, link_with: be_lib,
  install_rpath: rel_rpath,
  install: true, install_dir: libexecdir)

install_headers(['include/common_tools_be.h', 'include/common_tools_fe.h',
  'include/common_tools_shared.h', common_tools_version_h])
install_man(['doc/man/cti.1', 'doc/man/cti.3'])

common_tools_fe_pc = configure_file(input: 'pkgconfig/common_tools_fe.pc.in', output: 'common_tools_fe.pc',
  configuration: {'prefix': prefix, 'exec_prefix': prefix, 'libdir': prefix / libdir,
    'includedir': prefix / get_option('includedir'), 'VERSION': meson.project_version()})
common_tools_be_pc = configure_file(input: 'pkgconfig/common_tools_be.pc.in', output: 'common_tools_be.pc',
  configuration: {'prefix': prefix, 'exec_prefix': prefix, 'libdir': prefix / libdir,
    'includedir': prefix / get_option('includedir'), 'VERSION': meson.project_version()})
install_data(common_tools_fe_pc, install_dir: libdir / 'pkgconfig')
install_data(common_tools_be_pc, install_dir: libdir / 'pkgconfig')

googletest_subproject = cmake.subproject('googletest')
gmock_dep = googletest_subproject.dependency('gmock')
gtest_dep = googletest_subproject.dependency('gtest')
googletest_dep = declare_dependency(dependencies: [gmock_dep, gtest_dep])

libmock_a = static_library(
   'mock',
   sources: [
      './tests/mock/MockFrontend/Frontend.cpp'
   ],
   include_directories: [ inc_src, inc_public ],
   dependencies: [ googletest_dep, archive_dep ],
)

inc_moc = include_directories('tests/mock')


test('unit_tests', executable('unit_tests', 'tests/unit/unit_tests.cpp',
  cpp_args: ['-DINSTALL_PATH="' + prefix + '"'],
  include_directories: [inc_src, inc_public, inc_moc],
  dependencies: [archive_dep, threads_dep, googletest_dep],
  link_with: [fe_lib, be_lib, libmock_a], install: false))

test('flux_api_parse_tests',
  executable('flux_api_parse_tests', 'tests/unit/flux_api_parse_tests.cpp',
  include_directories: [inc_src, inc_public],
  dependencies: [archive_dep, threads_dep, googletest_dep], install: false))
