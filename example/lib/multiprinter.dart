// Re-export barrel so that `package:multiprinter/multiprinter.dart`
// (which, inside the example app, resolves to this file because the app is
// named `multiprinter`) provides all the same public symbols as the actual
// `multiprinter_package` library dependency.
export 'package:multiprinter_package/multiprinter.dart';
