// owner_screen.dart

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'role_based_router.dart';
import 'owner_dashboard_screen.dart';
import 'owner_transactions_screen.dart' as transactions;
import 'owner_inventory_screen.dart';
import 'settings_screen.dart'; // Pastikan file ini sudah ada
import 'widgets/custom_dialogs.dart';

class OwnerScreen extends StatefulWidget {
  const OwnerScreen({super.key});

  @override
  State<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends State<OwnerScreen> {
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();

  // Daftar Tab Halaman
  late final List<Widget> _widgetOptions = [
    const OwnerDashboardScreen(),                 // Index 0
    const transactions.OwnerTransactionsScreen(), // Index 1
    const OwnerInventoryScreen(),                 // Index 2
    const SettingsScreen(),                       // Index 3
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  // --- FUNGSI LOGOUT YANG SUDAH DIPERBAIKI (ANTI CRASH) ---
  Future<void> _handleLogout() async {
    // 1. Simpan context parent agar aman
    final parentContext = context;

    final confirmed = await showLogoutDialog(parentContext);

    // Stop jika user pilih Batal
    if (!confirmed) return;

    // 2. Cek Mounted sebelum proses async
    if (!mounted) return;

    await _apiService.logout();

    // 3. Cek Mounted lagi setelah proses async selesai
    // (Penting: Widget mungkin sudah dibuang saat menunggu API selesai)
    if (!mounted) return;

    // 4. Navigasi aman menggunakan parentContext
    Navigator.of(parentContext).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleBasedRouter()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan Judul AppBar berdasarkan Tab
    String title;
    switch (_selectedIndex) {
      case 0:
        title = 'Dashboard & Omzet';
        break;
      case 1:
        title = 'Riwayat Transaksi';
        break;
      case 2:
        title = 'Stok Analitik';
        break;
      default:
        title = 'Owner';
    }

    return Scaffold(
      // Logic AppBar:
      // Jika di tab Settings (index 3), sembunyikan AppBar parent (null)
      // agar tidak double dengan AppBar milik SettingsScreen.
      appBar: _selectedIndex == 3
          ? null
          : AppBar(
              title: Text(title),
              automaticallyImplyLeading: false, // Hilangkan tombol back
              actions: [
                // Tombol Logout di AppBar (Hanya muncul di Tab 0, 1, 2)
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  tooltip: 'Logout',
                  onPressed: _handleLogout,
                ),
              ],
            ),
      
      // Body Halaman
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),

      // Navigasi Bawah
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Wajib fixed biar teks 4 tab muncul
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Ringkasan'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Transaksi'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Stok'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}