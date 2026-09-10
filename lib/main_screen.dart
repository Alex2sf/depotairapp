import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'product_screen.dart';
import 'opname_screen.dart';
import 'api_service.dart';
import 'cash_transaction_screen.dart';
import 'close_shift_screen.dart';
import 'deposit_to_main_screen.dart';
import 'order_history_screen.dart';
import 'settings_screen.dart';
import 'stock_adjustment_screen.dart';
import 'cashier_purchase_screen.dart';
import 'order_detail_screen.dart';
import 'owner_shift_monitoring_screen.dart';
import 'widgets/cashier_reminder_dialog.dart';

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

  // Shift & Cash Data
  Map<String, dynamic>? _currentShiftData;
  int _activeOrdersCount = 0;
  bool _hideBalance = false;

  // Reminder Overdue
  final Map<String, DateTime> _snoozedOrders = {};
  bool _isCheckingReminder = false;
  static const int _overdueThresholdMinutes = 60; // 1 jam
  static const int _snoozeMinutes = 15;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _refreshHomeData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCashierOverdueOrders();
    });
  }

  Future<void> _refreshHomeData() async {
    await Future.wait([
      _fetchProfile(),
      _fetchCurrentShift(),
      _fetchOrdersSummary(),
    ]);
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await _apiService.getProfile();
      if (mounted && profile != null) {
        setState(() => _userProfile = profile);
      }
    } catch (_) {}
  }

  Future<void> _fetchCurrentShift() async {
    try {
      final result = await _apiService.getCurrentShift();
      if (mounted && result != null && result['success'] == true) {
        setState(() {
          _currentShiftData = result['shift'];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchOrdersSummary() async {
    try {
      final res = await _apiService.getOrderHistory();
      if (res != null && res['data'] is List) {
        final List<dynamic> orders = res['data'];
        int active = 0;
        for (var o in orders) {
          if (o is Map<String, dynamic>) {
            final st = (o['status'] ?? '').toString().toUpperCase();
            if (st != 'COMPLETE' && st != 'DONE' && st != 'CANCELLED' && st != 'DELIVERED') {
              active++;
            }
          }
        }
        if (mounted) {
          setState(() => _activeOrdersCount = active);
        }
      }
    } catch (_) {}
  }

  DateTime? _parseOrderTimestamp(String? timestampStr) {
    if (timestampStr == null || timestampStr.isEmpty) return null;
    try {
      return DateTime.parse(timestampStr).toLocal();
    } catch (_) {
      try {
        return DateFormat('dd/MM/yyyy HH:mm').parse(timestampStr);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _checkCashierOverdueOrders() async {
    if (!mounted || _isCheckingReminder || _selectedIndex != 0) return;

    try {
      final now = DateTime.now();
      final res = await _apiService.getOrderHistory();
      if (res == null || res['data'] == null) return;

      final List<dynamic> orders = res['data'] is List ? res['data'] : [];
      if (orders.isEmpty) return;

      Map<String, dynamic>? mostOverdueOrder;
      int maxMinutesElapsed = 0;

      for (var raw in orders) {
        if (raw is! Map<String, dynamic>) continue;
        final status = (raw['status'] ?? '').toString().toUpperCase();

        if (status == 'COMPLETE' ||
            status == 'DONE' ||
            status == 'CANCELLED' ||
            status == 'DELIVERED') {
          continue;
        }

        final orderNumber = raw['order_number']?.toString();
        if (orderNumber == null || orderNumber.isEmpty) continue;

        final snoozeUntil = _snoozedOrders[orderNumber];
        if (snoozeUntil != null && now.isBefore(snoozeUntil)) {
          continue;
        }

        final time = _parseOrderTimestamp(raw['ready_time']?.toString()) ??
            _parseOrderTimestamp(raw['created_at']?.toString());
        if (time == null) continue;

        final elapsed = now.difference(time).inMinutes;
        if (elapsed >= _overdueThresholdMinutes && elapsed > maxMinutesElapsed) {
          maxMinutesElapsed = elapsed;
          mostOverdueOrder = raw;
        }
      }

      if (mostOverdueOrder != null && mounted) {
        _isCheckingReminder = true;
        final orderNumber = mostOverdueOrder['order_number']?.toString() ?? '';

        final action = await showCashierReminderDialog(
          context: context,
          order: mostOverdueOrder,
          minutesElapsed: maxMinutesElapsed,
        );

        _isCheckingReminder = false;
        if (!mounted) return;

        if (action == CashierReminderAction.completeNow) {
          final success = await _apiService.completeOrderManual(orderNumber);
          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text("Pesanan #$orderNumber berhasil diselesaikan!")),
                    ],
                  ),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
              _refreshHomeData();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Gagal menyelesaikan pesanan #$orderNumber"),
                  backgroundColor: Colors.red.shade700,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } else if (action == CashierReminderAction.viewDetail) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderNumber: orderNumber),
            ),
          );
          _refreshHomeData();
        } else if (action == CashierReminderAction.snooze) {
          _snoozedOrders[orderNumber] = now.add(const Duration(minutes: _snoozeMinutes));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Pengingat #$orderNumber ditunda $_snoozeMinutes menit."),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.blueGrey.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (_) {
      _isCheckingReminder = false;
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      _refreshHomeData();
      _checkCashierOverdueOrders();
    }
  }

  void _navigateToInternal(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted && _selectedIndex == 0) {
      _refreshHomeData();
      _checkCashierOverdueOrders();
    }
  }

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  // --- WIDGET OPTIONS ---
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeDashboard();
      case 1:
        return const ProductScreen();
      case 2:
        return const OrderHistoryScreen();
      case 3:
        return const SettingsScreen();
      default:
        return _buildHomeDashboard();
    }
  }

  // --- HOME DASHBOARD TAB ---
  Widget _buildHomeDashboard() {
    final String greeting = _getGreeting();
    final String userName = _userProfile?['name'] ?? 'Kasir';
    final String userRole = (_userProfile?['role'] ?? 'kasir').toString().toUpperCase();
    final String dateNow = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    final num expectedCash = _currentShiftData?['expected_cash'] ?? 0;
    final num totalCashSales = _currentShiftData?['total_cash_sales'] ?? 0;
    final num totalPurchases = _currentShiftData?['total_purchases'] ?? 0;
    final bool isOwnerOrAdmin = userRole == 'OWNER' || userRole == 'ADMIN';

    return Container(
      color: const Color(0xFFF1F5F9), // Slate 100
      child: RefreshIndicator(
        onRefresh: _refreshHomeData,
        color: const Color(0xFF0284C7),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Column(
            children: [
              // 1. MODERN GRADIENT APP HEADER
              _buildHeader(greeting, userName, userRole, dateNow),

              // 2. HERO CARD: SALDO LACI & RINGKASAN SHIFT
              Transform.translate(
                offset: const Offset(0, -35),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildHeroShiftCard(expectedCash, totalCashSales, totalPurchases),
                ),
              ),

              // 3. ACTIVE ORDERS ALERT BANNER (JIKA ADA PESANAN GANTUNG)
              if (_activeOrdersCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _buildActiveOrdersBanner(),
                ),

              // 4. MENU CEPAT KATEGORI 1: LAYANAN & TRANSAKSI
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: "Transaksi & Kasir",
                      subtitle: "Operasional penjualan dan belanja kasir",
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionTile(
                            title: "Kasir POS",
                            subtitle: "Buat Pesanan",
                            icon: Icons.point_of_sale_rounded,
                            badgeColor: const Color(0xFF0284C7),
                            bgColor: const Color(0xFFE0F2FE),
                            onTap: () => _onItemTapped(1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionTile(
                            title: "Riwayat Nota",
                            subtitle: "Status Transaksi",
                            icon: Icons.receipt_long_rounded,
                            badgeColor: const Color(0xFF7C3AED),
                            bgColor: const Color(0xFFEDE9FE),
                            onTap: () => _onItemTapped(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFullWidthTile(
                      title: "Belanja Kasir (Uang Laci)",
                      subtitle: "Catat pembelian stok atau operasional dari laci kasir",
                      icon: Icons.shopping_bag_rounded,
                      badgeColor: const Color(0xFF0D9488),
                      bgColor: const Color(0xFFCCFBF1),
                      onTap: () => _navigateToInternal(const CashierPurchaseScreen()),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 5. MENU CEPAT KATEGORI 2: KAS & KEUANGAN
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: "Keuangan & Rekonsiliasi",
                      subtitle: "Kelola setoran kas dan tutup shift",
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionTile(
                            title: "Setor Kas",
                            subtitle: "Ke Kas Besar",
                            icon: Icons.account_balance_wallet_rounded,
                            badgeColor: const Color(0xFF6366F1),
                            bgColor: const Color(0xFFEEF2FF),
                            onTap: () => _navigateToInternal(const DepositToMainScreen()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionTile(
                            title: "Tutup Shift",
                            subtitle: "Rekonsiliasi Laci",
                            icon: Icons.lock_clock_rounded,
                            badgeColor: const Color(0xFFEA580C),
                            bgColor: const Color(0xFFFFEDD5),
                            onTap: () => _navigateToInternal(const CloseShiftScreen()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFullWidthTile(
                      title: "Catat Pengeluaran Lain",
                      subtitle: "Biaya listrik, konsumsi, atau modal kas depot",
                      icon: Icons.money_off_rounded,
                      badgeColor: const Color(0xFFE11D48),
                      bgColor: const Color(0xFFFFE4E6),
                      onTap: () => _navigateToInternal(const CashTransactionScreen()),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 6. MENU CEPAT KATEGORI 3: GUDANG & INVENTORI
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: "Gudang & Inventori",
                      subtitle: "Pantau fisik galon, tutup, dan tisu",
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionTile(
                            title: "Stok Opname",
                            subtitle: "Audit Fisik Galon",
                            icon: Icons.inventory_2_rounded,
                            badgeColor: const Color(0xFF059669),
                            bgColor: const Color(0xFFD1FAE5),
                            onTap: () => _navigateToInternal(const OpnameScreen()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionTile(
                            title: "Kelola Stok",
                            subtitle: "Restock & Rusak",
                            icon: Icons.sync_alt_rounded,
                            badgeColor: const Color(0xFFD97706),
                            bgColor: const Color(0xFFFEF3C7),
                            onTap: () => _navigateToInternal(const StockAdjustmentScreen()),
                          ),
                        ),
                      ],
                    ),
                    if (isOwnerOrAdmin) ...[
                      const SizedBox(height: 12),
                      _buildFullWidthTile(
                        title: "Monitoring Shift Kasir",
                        subtitle: "Pantau riwayat shift & setoran seluruh kasir",
                        icon: Icons.analytics_rounded,
                        badgeColor: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFDBEAFE),
                        onTap: () => _navigateToInternal(const OwnerShiftMonitoringScreen()),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // --- HEADER WIDGET ---
  Widget _buildHeader(String greeting, String userName, String userRole, String dateNow) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 54, 22, 58),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0A2540), // Deep Navy
            Color(0xFF075985), // Ocean Blue
            Color(0xFF0284C7), // Sky Blue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Greeting & Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          greeting,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.waving_hand_rounded, size: 14, color: Colors.amber),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Status Pill & Avatar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80), // Green 400
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          userRole,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, error, stackTrace) => const Icon(
                          Icons.person,
                          color: Color(0xFF0284C7),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Date & Depot Tagline Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, color: Colors.white.withValues(alpha: 0.9), size: 14),
                    const SizedBox(width: 8),
                    Text(
                      dateNow,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.water_drop, color: Colors.cyanAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "Depot Air Minum",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HERO SHIFT CARD ---
  Widget _buildHeroShiftCard(num expectedCash, num totalCashSales, num totalPurchases) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.12),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Saldo Laci Header + Eye Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0284C7), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Uang di Laci Kasir",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _hideBalance = !_hideBalance),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Icon(
                        _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 17,
                        color: Colors.blueGrey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _hideBalance ? "Tampilkan" : "Sembunyikan",
                        style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: Large Nominal
          Text(
            _hideBalance ? "••••••••••••" : _formatCurrency(expectedCash),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // Row 3: Sub Metrics (Penjualan, Belanja Laci, Pesanan Aktif)
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  label: "Penjualan Kas",
                  value: _formatCurrency(totalCashSales),
                  color: const Color(0xFF16A34A), // Green
                  icon: Icons.trending_up_rounded,
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildMetricItem(
                  label: "Belanja Laci",
                  value: _formatCurrency(totalPurchases),
                  color: const Color(0xFFDC2626), // Red
                  icon: Icons.shopping_cart_outlined,
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildMetricItem(
                  label: "Pesanan Aktif",
                  value: "$_activeOrdersCount Nota",
                  color: const Color(0xFF0284C7), // Blue
                  icon: Icons.pending_actions_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // --- ACTIVE ORDERS BANNER ---
  Widget _buildActiveOrdersBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Amber 50
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)), // Amber 200
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$_activeOrdersCount Pesanan Sedang Berjalan",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Periksa pesanan siap antar atau ambil di tempat",
                  style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _onItemTapped(2),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            child: const Text("Lihat"),
          ),
        ],
      ),
    );
  }

  // --- SECTION HEADER ---
  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
        ),
      ],
    );
  }

  // --- ACTION TILE 2-COLUMN ---
  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color badgeColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: badgeColor, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blueGrey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FULL WIDTH ACTION TILE ---
  Widget _buildFullWidthTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color badgeColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: badgeColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.blueGrey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.blueGrey.shade300),
            ],
          ),
        ),
      ),
    );
  }

  // --- BOTTOM NAV BAR ---
  Widget _buildBottomNav() {
    return Container(
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
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0284C7),
                );
              }
              return TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey.shade400,
              );
            }),
            indicatorColor: const Color(0xFFE0F2FE),
            backgroundColor: Colors.white,
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF0284C7)),
                label: "Beranda",
              ),
              NavigationDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale_rounded, color: Color(0xFF0284C7)),
                label: "Kasir",
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7)),
                label: "Riwayat",
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF0284C7)),
                label: "Pengaturan",
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SCAFFOLD UTAMA ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}