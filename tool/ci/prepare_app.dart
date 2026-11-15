/// Turns an app made by `flutter create` into the consumer the compat
/// workflow builds: copies the on-device workbook test into it.
///
/// Usage: `dart tool/ci/prepare_app.dart <app directory>`
///
/// The dependency on xlsxwriter is added separately with `flutter pub add`.
library;

import 'dart:io';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart tool/ci/prepare_app.dart <app directory>');
    exit(64);
  }
  final app = Directory(args.single);
  final ci = File.fromUri(Platform.script).parent;

  final to = File('${app.path}/integration_test/workbook_test.dart');
  to.parent.createSync(recursive: true);
  File('${ci.path}/integration_test/workbook_test.dart').copySync(to.path);
  print('prepared ${app.path}');
}
