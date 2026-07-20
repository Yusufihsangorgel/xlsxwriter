/*
 * Implementation of the C ABI shim declared in xlsxwriter_shim.h.
 *
 * Each wrapper forwards to libxlsxwriter. Row and column indices arrive as
 * 32-bit values and are narrowed to libxlsxwriter's `lxw_row_t` (uint32) and
 * `lxw_col_t` (uint16) here, so the flat boundary carries only `int32`-shaped
 * scalars. Colours are `lxw_color_t` (uint32); flag/style enums are `uint8`.
 */
#include "xlsxwriter_shim.h"

#include <stdlib.h>

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

int32_t xlsxw_add_table(void *worksheet, uint32_t first_row, uint32_t first_col,
                        uint32_t last_row, uint32_t last_col, const char *name,
                        const char *const *headers, int32_t num_columns,
                        int32_t no_header_row, int32_t no_autofilter,
                        int32_t no_banded_rows, int32_t banded_columns,
                        int32_t total_row, int32_t style_type) {
  lxw_table_options options = {0};
  if (name != NULL && name[0] != '\0') {
    options.name = (char *)name;
  }
  options.no_header_row = (uint8_t)no_header_row;
  options.no_autofilter = (uint8_t)no_autofilter;
  options.no_banded_rows = (uint8_t)no_banded_rows;
  options.banded_columns = (uint8_t)banded_columns;
  options.total_row = (uint8_t)total_row;
  options.style_type = (uint8_t)style_type;

  // libxlsxwriter names columns from the options, not from any header cells
  // already written, and defaults to "Column1", "Column2", ... So when the
  // caller supplies header names, build the NULL-terminated columns array it
  // expects. libxlsxwriter copies each header, so these locals are enough.
  lxw_table_column *column_structs = NULL;
  lxw_table_column **column_ptrs = NULL;
  if (headers != NULL && num_columns > 0) {
    column_structs =
        (lxw_table_column *)calloc((size_t)num_columns, sizeof(*column_structs));
    column_ptrs = (lxw_table_column **)calloc((size_t)num_columns + 1,
                                              sizeof(*column_ptrs));
    if (column_structs == NULL || column_ptrs == NULL) {
      free(column_structs);
      free(column_ptrs);
      return (int32_t)LXW_ERROR_MEMORY_MALLOC_FAILED;
    }
    for (int32_t i = 0; i < num_columns; i++) {
      column_structs[i].header = (char *)headers[i];
      column_ptrs[i] = &column_structs[i];
    }
    column_ptrs[num_columns] = NULL;  // terminates the array
    options.columns = column_ptrs;
  }

  int32_t result = (int32_t)worksheet_add_table(
      (lxw_worksheet *)worksheet, (lxw_row_t)first_row, (lxw_col_t)first_col,
      (lxw_row_t)last_row, (lxw_col_t)last_col, &options);

  free(column_structs);
  free(column_ptrs);
  return result;
}

/* --- Charts --------------------------------------------------------------- */

void *xlsxw_add_chart(void *workbook, int32_t chart_type) {
  /* Translate the shim's stable code to libxlsxwriter's enum here, so the Dart
   * side never depends on the LXW_CHART_* integer values. */
  uint8_t lxw_type;
  switch (chart_type) {
    case 0: lxw_type = LXW_CHART_COLUMN; break;
    case 1: lxw_type = LXW_CHART_BAR; break;
    case 2: lxw_type = LXW_CHART_LINE; break;
    case 3: lxw_type = LXW_CHART_AREA; break;
    case 4: lxw_type = LXW_CHART_PIE; break;
    case 5: lxw_type = LXW_CHART_DOUGHNUT; break;
    case 6: lxw_type = LXW_CHART_SCATTER; break;
    case 7: lxw_type = LXW_CHART_RADAR; break;
    default: lxw_type = LXW_CHART_COLUMN; break;
  }
  return (void *)workbook_add_chart((lxw_workbook *)workbook, lxw_type);
}

void *xlsxw_chart_add_series(void *chart, const char *categories,
                             const char *values) {
  /* `categories` NULL numbers the points 1..N; libxlsxwriter accepts it. */
  return (void *)chart_add_series((lxw_chart *)chart, categories, values);
}

void xlsxw_chart_series_set_name(void *series, const char *name) {
  chart_series_set_name((lxw_chart_series *)series, name);
}

void xlsxw_chart_title_set_name(void *chart, const char *name) {
  chart_title_set_name((lxw_chart *)chart, name);
}

void xlsxw_chart_axis_set_name(void *chart, int32_t axis, const char *name) {
  lxw_chart *c = (lxw_chart *)chart;
  chart_axis_set_name(axis == 0 ? c->x_axis : c->y_axis, name);
}

int32_t xlsxw_insert_chart(void *worksheet, uint32_t row, uint32_t col,
                           void *chart, double x_scale, double y_scale) {
  lxw_chart_options options = {0};
  options.x_scale = x_scale;
  options.y_scale = y_scale;
  return (int32_t)worksheet_insert_chart_opt((lxw_worksheet *)worksheet, row,
                                             (lxw_col_t)col, (lxw_chart *)chart,
                                             &options);
}

/* Inserts an image from an in-memory buffer at the given cell, scaled and
 * offset. libxlsxwriter copies the buffer, so the Dart side can free it once
 * this returns. `data` and `len` are the encoded PNG/JPEG bytes. */
int32_t xlsxw_insert_image_buffer(void *worksheet, uint32_t row, uint32_t col,
                                  const unsigned char *data, size_t len,
                                  double x_scale, double y_scale,
                                  int32_t x_offset, int32_t y_offset) {
  lxw_image_options options = {0};
  options.x_scale = x_scale;
  options.y_scale = y_scale;
  options.x_offset = x_offset;
  options.y_offset = y_offset;
  return (int32_t)worksheet_insert_image_buffer_opt(
      (lxw_worksheet *)worksheet, row, (lxw_col_t)col, data, len, &options);
}
