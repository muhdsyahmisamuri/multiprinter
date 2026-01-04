import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'core/di/injection_container.dart';
import 'presentation/providers/printer_provider.dart';

/// Main entry point for the MultiPrinter package.
///
/// This class provides convenient static methods and properties
/// to initialize and access the printer functionality.
///
/// ## Usage
///
/// Initialize the package in your app's main function:
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await MultiPrinter.init();
///   runApp(MyApp());
/// }
/// ```
///
/// Use the provider in your widget tree:
///
/// ```dart
/// MultiProvider(
///   providers: [
///     ChangeNotifierProvider(create: (_) => MultiPrinter.printerProvider),
///   ],
///   child: MyApp(),
/// )
/// ```
class MultiPrinter {
  MultiPrinter._();

  static bool _isInitialized = false;

  /// Whether the package has been initialized.
  static bool get isInitialized => _isInitialized;

  /// Initialize the MultiPrinter package.
  ///
  /// This must be called before using any other functionality.
  /// Typically called in your app's `main()` function after
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await MultiPrinter.init();
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<void> init() async {
    if (_isInitialized) return;

    await initDependencies();
    _isInitialized = true;
  }

  /// Get the PrinterProvider instance.
  ///
  /// The package must be initialized before calling this.
  /// Use this to add to your MultiProvider or access directly.
  ///
  /// ```dart
  /// final provider = MultiPrinter.printerProvider;
  /// await provider.scanBluetoothPrinters();
  /// ```
  static PrinterProvider get printerProvider {
    _ensureInitialized();
    return sl<PrinterProvider>();
  }

  /// Create a ChangeNotifierProvider for the PrinterProvider.
  ///
  /// Use this convenience method in your MultiProvider setup:
  ///
  /// ```dart
  /// MultiProvider(
  ///   providers: [
  ///     MultiPrinter.createPrinterProvider(),
  ///   ],
  ///   child: MyApp(),
  /// )
  /// ```
  static ChangeNotifierProvider<PrinterProvider> createPrinterProvider() {
    _ensureInitialized();
    return ChangeNotifierProvider(create: (_) => sl<PrinterProvider>());
  }

  /// Reset the package state.
  ///
  /// This is useful for testing or when you need to reinitialize.
  static Future<void> reset() async {
    if (!_isInitialized) return;

    await sl.reset();
    _isInitialized = false;
  }

  static void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'MultiPrinter has not been initialized. '
        'Call MultiPrinter.init() before using any functionality.',
      );
    }
  }
}

/// Extension on BuildContext for easy access to PrinterProvider.
extension MultiPrinterContext on BuildContext {
  /// Get the PrinterProvider from the widget tree.
  ///
  /// ```dart
  /// final provider = context.printerProvider;
  /// ```
  PrinterProvider get printerProvider => read<PrinterProvider>();

  /// Watch the PrinterProvider for changes.
  ///
  /// ```dart
  /// final provider = context.watchPrinterProvider;
  /// ```
  PrinterProvider get watchPrinterProvider => watch<PrinterProvider>();
}

