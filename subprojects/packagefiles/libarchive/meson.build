project('libarchive', 'c', meson_version : '>=0.56.0')

mod = import('unstable-external_project')

autoreconf = find_program('autoreconf')

run_command(
  autoreconf,
  '--force',
  '--install',
  '--verbose',
  check: true,
)

p = mod.add_project('configure',
  configure_options : [
    '--prefix=@PREFIX@',
    '--libdir=@PREFIX@/@LIBDIR@',
    '--with-pic',
    '--without-expat',
    '--without-xml2',
    '--without-openssl',
    '--without-nettle',
    '--without-lzo2',
    '--without-lzma',
    '--without-libiconv-prefix',
    '--without-iconv',
    '--without-bz2lib',
    '--disable-bsdtar',
    '--disable-bsdcpio',
    '--disable-acl'
  ],
  verbose: true,
)

archive_dep = p.dependency('archive')
meson.override_dependency('libarchive', archive_dep)
