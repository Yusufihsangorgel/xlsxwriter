/*
 * Thin C ABI shim over libxlsxwriter.
 *
 * The Dart side binds these `xlsxw_*` functions rather than libxlsxwriter's
 * API directly, for two reasons:
 *
 *   1. Windows exports. A DLL exports nothing by default under MSVC, and
 *      libxlsxwriter's public functions are not marked `__declspec(dllexport)`.
 *      Every entry point here is marked exported, so `@Native` symbol lookup
 *      resolves on Windows the same way it does on macOS/Linux. libxlsxwriter's
 *      own symbols stay internal to the produced library.
 *
 *   2. A flat ABI. Rows/columns/colours/flags cross the boundary as plain
 *      fixed-width integers and dates as six scalars, so the Dart bindings need
 *      no knowledge of libxlsxwriter's structs (`lxw_datetime`,
 *      `lxw_workbook_options`) or its enum widths.
 *
 * Handles are opaque `void*`. Write functions return `int32_t`, a value of the
 * `lxw_error` enum (0 == LXW_NO_ERROR); pair with `xlsxw_strerror`.
 */
#ifndef XLSXWRITER_SHIM_H
#define XLSXWRITER_SHIM_H

#include <stdint.h>

#if defined(_WIN32)
#define XLSXW_EXPORT __declspec(dllexport)
#else
#define XLSXW_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Workbook lifecycle. */
XLSXW_EXPORT void *xlsxw_workbook_new(const char *filename);
XLSXW_EXPORT void *xlsxw_workbook_new_constant_memory(const char *filename);
XLSXW_EXPORT void *xlsxw_add_worksheet(void *workbook, const char *name);
XLSXW_EXPORT void *xlsxw_add_format(void *workbook);
XLSXW_EXPORT int32_t xlsxw_close(void *workbook);
XLSXW_EXPORT void xlsxw_workbook_free(void *workbook);

/* Cell writers. `format` may be NULL. */
XLSXW_EXPORT int32_t xlsxw_write_string(void *worksheet, uint32_t row,
                                        uint32_t col, const char *value,
                                        void *format);
XLSXW_EXPORT int32_t xlsxw_write_number(void *worksheet, uint32_t row,
                                        uint32_t col, double value,
                                        void *format);
XLSXW_EXPORT int32_t xlsxw_write_boolean(void *worksheet, uint32_t row,
                                         uint32_t col, int32_t value,
                                         void *format);
XLSXW_EXPORT int32_t xlsxw_write_formula(void *worksheet, uint32_t row,
                                         uint32_t col, const char *formula,
                                         void *format);
XLSXW_EXPORT int32_t xlsxw_write_datetime(void *worksheet, uint32_t row,
                                          uint32_t col, int32_t year,
                                          int32_t month, int32_t day,
                                          int32_t hour, int32_t min, double sec,
                                          void *format);
XLSXW_EXPORT int32_t xlsxw_write_url(void *worksheet, uint32_t row,
                                     uint32_t col, const char *url,
                                     void *format);
XLSXW_EXPORT int32_t xlsxw_write_blank(void *worksheet, uint32_t row,
                                       uint32_t col, void *format);

/* Layout. */
XLSXW_EXPORT int32_t xlsxw_set_column(void *worksheet, uint32_t first_col,
                                      uint32_t last_col, double width,
                                      void *format);
XLSXW_EXPORT int32_t xlsxw_set_row(void *worksheet, uint32_t row, double height,
                                   void *format);
XLSXW_EXPORT int32_t xlsxw_merge_range(void *worksheet, uint32_t first_row,
                                       uint32_t first_col, uint32_t last_row,
                                       uint32_t last_col, const char *value,
                                       void *format);
XLSXW_EXPORT void xlsxw_freeze_panes(void *worksheet, uint32_t row,
                                     uint32_t col);

/* Format attributes. */
XLSXW_EXPORT void xlsxw_format_set_bold(void *format);
XLSXW_EXPORT void xlsxw_format_set_italic(void *format);
XLSXW_EXPORT void xlsxw_format_set_underline(void *format, int32_t style);
XLSXW_EXPORT void xlsxw_format_set_font_name(void *format, const char *name);
XLSXW_EXPORT void xlsxw_format_set_font_size(void *format, double size);
XLSXW_EXPORT void xlsxw_format_set_font_color(void *format, int32_t color);
XLSXW_EXPORT void xlsxw_format_set_bg_color(void *format, int32_t color);
XLSXW_EXPORT void xlsxw_format_set_num_format(void *format, const char *value);
XLSXW_EXPORT void xlsxw_format_set_align(void *format, int32_t alignment);
XLSXW_EXPORT void xlsxw_format_set_text_wrap(void *format);
XLSXW_EXPORT void xlsxw_format_set_border(void *format, int32_t style);
XLSXW_EXPORT void xlsxw_format_set_border_color(void *format, int32_t color);

/* Human-readable message for an `lxw_error` value. Static storage; do not
 * free. */
XLSXW_EXPORT const char *xlsxw_strerror(int32_t error_code);

#ifdef __cplusplus
}
#endif

#endif /* XLSXWRITER_SHIM_H */
