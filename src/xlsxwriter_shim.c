/*
 * Implementation of the C ABI shim declared in xlsxwriter_shim.h.
 *
 * Each wrapper forwards to libxlsxwriter. Row and column indices arrive as
 * 32-bit values and are narrowed to libxlsxwriter's `lxw_row_t` (uint32) and
 * `lxw_col_t` (uint16) here, so the flat boundary carries only `int32`-shaped
 * scalars. Colours are `lxw_color_t` (uint32); flag/style enums are `uint8`.
 */
#include "xlsxwriter_shim.h"

#include "xlsxwriter.h"

void *xlsxw_workbook_new(const char *filename) {
  return (void *)workbook_new(filename);
}

void *xlsxw_workbook_new_constant_memory(const char *filename) {
  lxw_workbook_options options = {0};
  options.constant_memory = LXW_TRUE;
  return (void *)workbook_new_opt(filename, &options);
}

void *xlsxw_add_worksheet(void *workbook, const char *name) {
  /* `name` NULL lets libxlsxwriter assign the default "SheetN". */
  return (void *)workbook_add_worksheet((lxw_workbook *)workbook, name);
}

void *xlsxw_add_format(void *workbook) {
  return (void *)workbook_add_format((lxw_workbook *)workbook);
}

int32_t xlsxw_close(void *workbook) {
  return (int32_t)workbook_close((lxw_workbook *)workbook);
}

void xlsxw_workbook_free(void *workbook) {
  /* Reclaims memory without writing the file. Used by the Dart finalizer when
   * a workbook is garbage-collected without close(). */
  lxw_workbook_free((lxw_workbook *)workbook);
}

int32_t xlsxw_write_string(void *worksheet, uint32_t row, uint32_t col,
                           const char *value, void *format) {
  return (int32_t)worksheet_write_string((lxw_worksheet *)worksheet, row,
                                         (lxw_col_t)col, value,
                                         (lxw_format *)format);
}

int32_t xlsxw_write_number(void *worksheet, uint32_t row, uint32_t col,
                           double value, void *format) {
  return (int32_t)worksheet_write_number((lxw_worksheet *)worksheet, row,
                                         (lxw_col_t)col, value,
                                         (lxw_format *)format);
}

int32_t xlsxw_write_boolean(void *worksheet, uint32_t row, uint32_t col,
                            int32_t value, void *format) {
  return (int32_t)worksheet_write_boolean((lxw_worksheet *)worksheet, row,
                                          (lxw_col_t)col, value,
                                          (lxw_format *)format);
}

int32_t xlsxw_write_formula(void *worksheet, uint32_t row, uint32_t col,
                            const char *formula, void *format) {
  return (int32_t)worksheet_write_formula((lxw_worksheet *)worksheet, row,
                                          (lxw_col_t)col, formula,
                                          (lxw_format *)format);
}

int32_t xlsxw_write_datetime(void *worksheet, uint32_t row, uint32_t col,
                             int32_t year, int32_t month, int32_t day,
                             int32_t hour, int32_t min, double sec,
                             void *format) {
  lxw_datetime datetime;
  datetime.year = year;
  datetime.month = month;
  datetime.day = day;
  datetime.hour = hour;
  datetime.min = min;
  datetime.sec = sec;
  return (int32_t)worksheet_write_datetime((lxw_worksheet *)worksheet, row,
                                           (lxw_col_t)col, &datetime,
                                           (lxw_format *)format);
}

int32_t xlsxw_write_url(void *worksheet, uint32_t row, uint32_t col,
                        const char *url, void *format) {
  return (int32_t)worksheet_write_url((lxw_worksheet *)worksheet, row,
                                      (lxw_col_t)col, url,
                                      (lxw_format *)format);
}

int32_t xlsxw_write_blank(void *worksheet, uint32_t row, uint32_t col,
                          void *format) {
  return (int32_t)worksheet_write_blank((lxw_worksheet *)worksheet, row,
                                        (lxw_col_t)col, (lxw_format *)format);
}

int32_t xlsxw_set_column(void *worksheet, uint32_t first_col, uint32_t last_col,
                         double width, void *format) {
  return (int32_t)worksheet_set_column((lxw_worksheet *)worksheet,
                                       (lxw_col_t)first_col, (lxw_col_t)last_col,
                                       width, (lxw_format *)format);
}

int32_t xlsxw_set_row(void *worksheet, uint32_t row, double height,
                      void *format) {
  return (int32_t)worksheet_set_row((lxw_worksheet *)worksheet, row, height,
                                    (lxw_format *)format);
}

int32_t xlsxw_merge_range(void *worksheet, uint32_t first_row,
                          uint32_t first_col, uint32_t last_row,
                          uint32_t last_col, const char *value, void *format) {
  return (int32_t)worksheet_merge_range(
      (lxw_worksheet *)worksheet, first_row, (lxw_col_t)first_col, last_row,
      (lxw_col_t)last_col, value, (lxw_format *)format);
}

void xlsxw_freeze_panes(void *worksheet, uint32_t row, uint32_t col) {
  worksheet_freeze_panes((lxw_worksheet *)worksheet, row, (lxw_col_t)col);
}

void xlsxw_format_set_bold(void *format) {
  format_set_bold((lxw_format *)format);
}

void xlsxw_format_set_italic(void *format) {
  format_set_italic((lxw_format *)format);
}

void xlsxw_format_set_underline(void *format, int32_t style) {
  format_set_underline((lxw_format *)format, (uint8_t)style);
}

void xlsxw_format_set_font_name(void *format, const char *name) {
  format_set_font_name((lxw_format *)format, name);
}

void xlsxw_format_set_font_size(void *format, double size) {
  format_set_font_size((lxw_format *)format, size);
}

void xlsxw_format_set_font_color(void *format, int32_t color) {
  format_set_font_color((lxw_format *)format, (lxw_color_t)color);
}

void xlsxw_format_set_bg_color(void *format, int32_t color) {
  format_set_bg_color((lxw_format *)format, (lxw_color_t)color);
}

void xlsxw_format_set_num_format(void *format, const char *value) {
  format_set_num_format((lxw_format *)format, value);
}

void xlsxw_format_set_align(void *format, int32_t alignment) {
  format_set_align((lxw_format *)format, (uint8_t)alignment);
}

void xlsxw_format_set_text_wrap(void *format) {
  format_set_text_wrap((lxw_format *)format);
}

void xlsxw_format_set_border(void *format, int32_t style) {
  format_set_border((lxw_format *)format, (uint8_t)style);
}

void xlsxw_format_set_border_color(void *format, int32_t color) {
  format_set_border_color((lxw_format *)format, (lxw_color_t)color);
}

const char *xlsxw_strerror(int32_t error_code) {
  return lxw_strerror((lxw_error)error_code);
}
