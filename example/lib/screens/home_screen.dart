import 'package:flutter/material.dart';
import 'package:multiprinter/multiprinter.dart';
import 'package:provider/provider.dart';

import 'printers_screen.dart';
import 'scan_screen.dart';
import 'print_screen.dart';

/// Main home screen with navigation to all features
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    PrintersScreen(),
    ScanScreen(),
    PrintScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Check permissions and load registered printers on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PrinterProvider>();
      provider.checkPermissions();
      provider.loadRegisteredPrinters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.print_outlined),
            selectedIcon: Icon(Icons.print),
            label: 'Printers',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Print',
          ),
        ],
      ),
    );
  }
}
