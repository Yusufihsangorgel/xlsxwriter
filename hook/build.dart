import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Compiles the FFI shim together with the vendored libxlsxwriter engine and a
/// vendored copy of zlib into one dynamic library at build time.
///
/// The translation-unit lists are the exact sets each project's own build
/// system compiles; nothing is generated here. Include roots cover the
/// libxlsxwriter headers (so its internal `#include "xlsxwriter/..."` and
/// `#include "third_party/..."` paths resolve), the minizip sources, and the
/// vendored zlib headers (libxlsxwriter and minizip `#include "zlib.h"` and
/// `<zlib.h>`). zlib is vendored and compiled on every platform because
/// Windows has no system zlib.
void main(List<String> args) async {
  await build(args, (input, output) async {
    final targetOS = input.config.code.targetOS;

    /// libxlsxwriter core, the 26 units its CMake `LIBXLSXWRITER_SOURCES`
    /// builds.
    const libxlsxwriterSources = <String>[
      'src/third_party/libxlsxwriter/src/app.c',
      'src/third_party/libxlsxwriter/src/chart.c',
      'src/third_party/libxlsxwriter/src/chartsheet.c',
      'src/third_party/libxlsxwriter/src/comment.c',
      'src/third_party/libxlsxwriter/src/content_types.c',
      'src/third_party/libxlsxwriter/src/core.c',
      'src/third_party/libxlsxwriter/src/custom.c',
      'src/third_party/libxlsxwriter/src/drawing.c',
      'src/third_party/libxlsxwriter/src/format.c',
      'src/third_party/libxlsxwriter/src/hash_table.c',
      'src/third_party/libxlsxwriter/src/metadata.c',
      'src/third_party/libxlsxwriter/src/packager.c',
      'src/third_party/libxlsxwriter/src/relationships.c',
      'src/third_party/libxlsxwriter/src/rich_value.c',
      'src/third_party/libxlsxwriter/src/rich_value_rel.c',
      'src/third_party/libxlsxwriter/src/rich_value_structure.c',
      'src/third_party/libxlsxwriter/src/rich_value_types.c',
      'src/third_party/libxlsxwriter/src/shared_strings.c',
      'src/third_party/libxlsxwriter/src/styles.c',
      'src/third_party/libxlsxwriter/src/table.c',
      'src/third_party/libxlsxwriter/src/theme.c',
      'src/third_party/libxlsxwriter/src/utility.c',
      'src/third_party/libxlsxwriter/src/vml.c',
      'src/third_party/libxlsxwriter/src/workbook.c',
      'src/third_party/libxlsxwriter/src/worksheet.c',
      'src/third_party/libxlsxwriter/src/xmlwriter.c',
    ];

    /// The minizip units libxlsxwriter needs for the zip container. `iowin32.c`
    /// is the Windows file-IO backend and is only referenced on Windows.
    final minizipSources = <String>[
      'src/third_party/libxlsxwriter/third_party/minizip/ioapi.c',
      'src/third_party/libxlsxwriter/third_party/minizip/zip.c',
      if (targetOS == OS.windows)
        'src/third_party/libxlsxwriter/third_party/minizip/iowin32.c',
    ];

    const otherThirdParty = <String>[
      'src/third_party/libxlsxwriter/third_party/md5/md5.c',
      'src/third_party/libxlsxwriter/third_party/tmpfileplus/tmpfileplus.c',
      'src/third_party/libxlsxwriter/third_party/dtoa/emyg_dtoa.c',
    ];

    /// zlib 1.3.1 core, the units its own Makefile builds into `libz`.
    const zlibSources = <String>[
      'src/third_party/zlib/adler32.c',
      'src/third_party/zlib/compress.c',
      'src/third_party/zlib/crc32.c',
      'src/third_party/zlib/deflate.c',
      'src/third_party/zlib/gzclose.c',
      'src/third_party/zlib/gzlib.c',
      'src/third_party/zlib/gzread.c',
      'src/third_party/zlib/gzwrite.c',
      'src/third_party/zlib/infback.c',
      'src/third_party/zlib/inffast.c',
      'src/third_party/zlib/inflate.c',
      'src/third_party/zlib/inftrees.c',
      'src/third_party/zlib/trees.c',
      'src/third_party/zlib/uncompr.c',
      'src/third_party/zlib/zutil.c',
    ];

    final builder = CBuilder.library(
      name: 'xlsxwriter',
      assetName: 'src/bindings.dart',
      sources: [
        'src/xlsxwriter_shim.c',
        ...libxlsxwriterSources,
        ...minizipSources,
        ...otherThirdParty,
        ...zlibSources,
      ],
      includes: [
        'src',
        'src/third_party/libxlsxwriter/include',
        'src/third_party/libxlsxwriter/third_party',
        'src/third_party/zlib',
      ],
      defines: {
        // Release define: disables asserts in libxlsxwriter and zlib.
        'NDEBUG': null,
        // zlib's `configure` sets this on Unix; without it the `gz*` helpers
        // never include <unistd.h> and fail to find read/write/lseek/close.
        // Windows uses its own <io.h> path inside gzguts.h, so leave it unset
        // there.
        if (targetOS != OS.windows) 'HAVE_UNISTD_H': null,
        // Under -std=c11 glibc sets __STRICT_ANSI__ and hides its POSIX
        // extensions, so tmpfileplus loses fdopen, P_tmpdir and S_IFDIR.
        // _GNU_SOURCE turns them back on. macOS headers expose them without
        // it, and it is harmless there; Windows does not use this path.
        if (targetOS != OS.windows) '_GNU_SOURCE': null,
        // Quiet MSVC's fopen/strcpy deprecation errors in zlib, minizip and
        // tmpfileplus, and keep <windows.h> from shadowing min/max.
        if (targetOS == OS.windows) '_CRT_SECURE_NO_WARNINGS': null,
        if (targetOS == OS.windows) 'NOMINMAX': null,
      },
      language: Language.c,
      std: 'c11',
    );
    await builder.run(input: input, output: output);
  });
}
