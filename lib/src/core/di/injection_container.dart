import 'package:get_it/get_it.dart';

import '../../data/datasources/printer_data_source.dart';
import '../../data/repositories/printer_repository_impl.dart';
import '../../domain/repositories/printer_repository.dart';
import '../../domain/usecases/connect_printer_usecase.dart';
import '../../domain/usecases/manage_printers_usecase.dart';
import '../../domain/usecases/print_usecase.dart';
import '../../domain/usecases/scan_printers_usecase.dart';
import '../../presentation/providers/printer_provider.dart';

/// Global service locator instance
final sl = GetIt.instance;

/// Initialize all dependencies
Future<void> initDependencies() async {
  // Data Sources
  sl.registerLazySingleton<PrinterDataSource>(() => PrinterDataSource());

  // Repositories
  sl.registerLazySingleton<PrinterRepository>(
    () => PrinterRepositoryImpl(dataSource: sl()),
  );

  // Use Cases
  sl.registerLazySingleton(() => ScanPrintersUseCase(sl()));
  sl.registerLazySingleton(() => ConnectPrinterUseCase(sl()));
  sl.registerLazySingleton(() => ManagePrintersUseCase(sl()));
  sl.registerLazySingleton(() => PrintUseCase(sl()));

  // Providers
  sl.registerFactory(
    () => PrinterProvider(
      scanUseCase: sl(),
      connectUseCase: sl(),
      manageUseCase: sl(),
      printUseCase: sl(),
    ),
  );
}

/// Get PrinterProvider instance
PrinterProvider get printerProvider => sl<PrinterProvider>();

