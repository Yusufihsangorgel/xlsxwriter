# Vendored third-party C sources

This package compiles its native library from vendored C source at build time
(see `hook/build.dart`). Nothing here is downloaded or generated during the
build, so the package is self-contained and reproducible on macOS, Linux, and
Windows with only a C toolchain.

## libxlsxwriter 1.2.2

- Upstream: https://github.com/jmcnamara/libxlsxwriter
- Author: John McNamara
- License: BSD 2-Clause (see `libxlsxwriter/License.txt`)
- Location: `libxlsxwriter/`

libxlsxwriter is the Excel `.xlsx` writer engine this package binds to. The
vendored tree keeps the upstream include layout (`include/xlsxwriter.h`,
`include/xlsxwriter/*.h`, `include/xlsxwriter/third_party/*.h`) so the library's
own `#include "xlsxwriter/..."` paths resolve unchanged.

Included:

- `src/*.c` (26 translation units): the core engine.
- `third_party/minizip/{ioapi,zip,iowin32}.c` and headers: the zip container
  writer. `iowin32.c` is compiled on Windows only.
- `third_party/md5/md5.c`: content hashing for de-duplicated drawings.
- `third_party/tmpfileplus/tmpfileplus.c`: portable temp files for the
  constant-memory mode.
- `third_party/dtoa/emyg_dtoa.c`: fast, locale-independent number formatting.

The upstream `chart`/`comment`/`image` example programs and generators, the
CMake/Make/Zig build files, tests, and docs are not vendored.

Bundled sub-licenses (all permissive): minizip (zlib license), md5
(BSD-style / public domain, Regents of the University of California), dtoa and
tmpfileplus (permissive). Their notices are in the respective source files and
in `libxlsxwriter/License.txt`.

## zlib 1.3.1

- Upstream: https://github.com/madler/zlib
- Authors: Jean-loup Gailly and Mark Adler
- License: zlib license (see `zlib/LICENSE`)
- Location: `zlib/`
- Source tarball SHA-256:
  `9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23`

libxlsxwriter needs zlib but does not bundle it, and Windows has no system
zlib, so zlib is vendored and compiled from source on every platform. This is
the ~15 core translation units plus their headers; the pre-generated `zconf.h`
that ships in the release tarball is used as-is (no `configure` step). The
build hook defines `HAVE_UNISTD_H` on non-Windows targets, which is what zlib's
own `configure` sets, so the `gz*` file helpers find `read`/`write`/`lseek`.
