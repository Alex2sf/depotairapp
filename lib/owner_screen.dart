import 'package:flutter/material.dart';
import 'owner_dashboard_screen.dart';
import 'owner_shift_monitoring_screen.dart';
import 'owner_transactions_screen.dart' as transactions;
import 'owner_inventory_screen.dart';
import 'settings_screen.dart';

class OwnerScreen extends StatefulWidget {
  final int initialIndex;
  const OwnerScreen({super.key, this.initialIndex = 0});

  @override
  State<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends State<OwnerScreen> {
  int _selectedIndex = 0;

  // 5 Tab Halaman untuk Owner & Admin
  late final List<Widget> _widgetOptions = [
    OwnerDashboardScreen(onNavigateToShiftTab: () => _onItemTapped(1)), // Index 0: Ringkasan
    const OwnerShiftMonitoringScreen(),                                // Index 1: Shift & Setor
    const transactions.OwnerTransactionsScreen(),                      // Index 2: Transaksi
    const OwnerInventoryScreen(),                                      // Index 3: Stok
    const SettingsScreen(),                                            // Index 4: Pengaturan
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      // Setiap halaman memiliki header/AppBar masing-masing yang sudah terintegrasi rapi
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),

      // 5 Navigasi Bawah Modern
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 15,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          minimum: const EdgeInsets.only(bottom: 6),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: const Color(0xFF0284C7),
            unselectedItemColor: Colors.blueGrey.shade400,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10.5),
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.space_dashboard_outlined),
                activeIcon: Icon(Icons.space_dashboard_rounded),
                label: 'Ringkasan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment_ind_outlined),
                activeIcon: Icon(Icons.assignment_ind_rounded),
                label: 'Shift & Setor',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long_rounded),
                label: 'Transaksi',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2_rounded),
                label: 'Stok',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings_rounded),
                label: 'Pengaturan',
              ),
            ],
          ),
        ),
      ),
    );
  }
}