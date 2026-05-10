import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'product_screen.dart';
import 'opname_screen.dart';
import 'api_service.dart';
import 'login_screen.dart';
import 'cash_transaction_screen.dart';
import 'close_shift_screen.dart';
import 'cash_dashboard_screen.dart';
import 'order_history_screen.dart';
import 'settings_screen.dart';
import 'widgets/custom_dialogs.dart';
import 'stock_adjustment_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // 0: Home, 1: POS, 2: History, 3: Settings
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
     final profile = await _apiService.getProfile();
     if (mounted && profile != null) {
       setState(() => _userProfile = profile);
     }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showLogoutDialog(context);
    if (!confirmed) return;

    await _apiService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _navigateToInternal(Widget page) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
  
  // --- WIDGET OPTIONS ---
  Widget _buildBody() {
     switch (_selectedIndex) {
       case 0: return _buildHomeDashboard();
       case 1: return const ProductScreen();
       case 2: return const OrderHistoryScreen();
       case 3: return const SettingsScreen();
       default: return _buildHomeDashboard();
     }
  }

  // --- HOME DASHBOARD TAB ---
  Widget _buildHomeDashboard() {
    final String greeting = _getGreeting();
    final String userName = _userProfile?['name'] ?? 'Kasir';
    final String dateNow = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          children: [
             // HEADER GRADIENT
             Container(
               padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
               decoration: BoxDecoration(
                 gradient: LinearGradient(
                   colors: [Colors.blue.shade800, Colors.blue.shade500],
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight
                 ),
                 borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(userName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                         ]),
                         Container(
                           padding: const EdgeInsets.all(2),
                           decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                           child: CircleAvatar(backgroundColor: Colors.blue.shade100, child: const Icon(Icons.person, color: Colors.blue)),
                         )
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                         color: Colors.white.withOpacity(0.15),
                         borderRadius: BorderRadius.circular(12)
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(dateNow, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                 ],
               ),
             ),

             // QUICK ACTIONS GRID
             Padding(
               padding: const EdgeInsets.all(20),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    const Text("Menu Cepat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                      children: [
                         _quickActionCard("Buat Pesanan", Icons.add_shopping_cart, Colors.blue, () => _onItemTapped(1)),
                         _quickActionCard("Kelola Kas", Icons.dashboard_customize_outlined, Colors.indigo, () => _navigateToInternal(const CashDashboardScreen())),
                         _quickActionCard("Tutup Shift", Icons.lock_clock_outlined, Colors.orange, () => _navigateToInternal(const CloseShiftScreen())),
                         _quickActionCard("Stok Opname", Icons.inventory_2_outlined, Colors.teal, () => _navigateToInternal(const OpnameScreen())),
                         _quickActionCard("Kelola Stok", Icons.sync_alt, Colors.deepOrange, () => _navigateToInternal(const StockAdjustmentScreen())),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    const Text("Lainnya", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 12),
                    _listActionItem("Riwayat Transaksi", Icons.receipt_long, Colors.purple, () => _onItemTapped(2)),
                    _listActionItem("Catat Pengeluaran", Icons.money_off, Colors.red, () => _navigateToInternal(const CashTransactionScreen())),
                 ],
               ),
             )
          ],
        ),
      ),
    );
  }
  
  Widget _quickActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                 child: Icon(icon, color: color, size: 28),
               ),
               const SizedBox(height: 12),
               Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      );
  }

  Widget _listActionItem(String title, IconData icon, Color color, VoidCallback onTap) {
      return Card(
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          onTap: onTap,
          leading: Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
             child: Icon(icon, color: color),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ),
      );
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi,';
    if (hour < 15) return 'Selamat Siang,';
    if (hour < 18) return 'Selamat Sore,';
    return 'Selamat Malam,';
  }

  // --- SCAFFOLD UTAMA ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0,-2))],
        ),
        child: SafeArea(
          // Force layout up by adding minimum bottom padding
          minimum: const EdgeInsets.only(bottom: 12), 
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              labelTextStyle: MaterialStateProperty.all(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              indicatorColor: Colors.blue.shade100,
              backgroundColor: Colors.white,
            ),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white, 
              elevation: 0, 
              // height removed to let it adjust
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                 NavigationDestination(
                   icon: const Icon(Icons.home_outlined),
                   selectedIcon: Icon(Icons.home_filled, color: Colors.blue.shade800),
                   label: "Home"
                 ),
                 NavigationDestination(
                   icon: const Icon(Icons.shopping_cart_outlined),
                   selectedIcon: Icon(Icons.shopping_cart, color: Colors.blue.shade800),
                   label: "Kasir"
                 ),
                 NavigationDestination(
                   icon: const Icon(Icons.history_outlined), 
                   selectedIcon: Icon(Icons.history, color: Colors.blue.shade800),
                   label: "Riwayat"
                 ),
                 NavigationDestination(
                   icon: const Icon(Icons.settings_outlined),
                   selectedIcon: Icon(Icons.settings, color: Colors.blue.shade800),
                   label: "Settings"
                 ),
              ],
            ),
          ),
        ),
      ),
      

    );
  }


}