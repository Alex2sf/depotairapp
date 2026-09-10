import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'owner_shift_monitoring_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToShiftTab;
  const OwnerDashboardScreen({super.key, this.onNavigateToShiftTab});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  // Default: Hari Ini
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    final String? start = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null;
    final String? end = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;

    final result = await _apiService.getOwnerDashboard(startDate: start, endDate: end);
    if (mounted) {
      setState(() {
        _dashboardData = result;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF0284C7),
            colorScheme: const ColorScheme.light(primary: Color(0xFF0284C7)),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchDashboardData();
    }
  }

  String _formatCurrency(num amount) =>
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);

  String _formatDate(DateTime? date) =>
      date == null ? '-' : DateFormat('dd MMM yyyy', 'id_ID').format(date);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        color: const Color(0xFF0284C7),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Column(
            children: [
              // 1. MODERN HEADER GRADIENT WITH DATE PICKER
              _buildHeader(),

              // 2. HERO CARD: TOTAL OMZET (OVERLAPPING)
              Transform.translate(
                offset: const Offset(0, -32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _isLoading
                      ? _buildLoadingCard()
                      : _buildHeroOmzetCard(_dashboardData?['omzet'] ?? 0),
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                  ),
                )
              else if (_dashboardData == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.blueGrey),
                        const SizedBox(height: 12),
                        const Text(
                          "Gagal memuat data ringkasan",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _fetchDashboardData,
                          child: const Text("Coba Lagi"),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildDashboardBody(),
                ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 54, 22, 54),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.insights_rounded, size: 16, color: Colors.cyanAccent),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Panel Pemilik Depot",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Ringkasan Bisnis",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
                  onPressed: _selectDateRange,
                  tooltip: 'Pilih Rentang Tanggal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Date Range Selector Pill
          GestureDetector(
            onTap: _selectDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.date_range_rounded, color: Colors.cyanAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "${_formatDate(_startDate)}  —  ${_formatDate(_endDate)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF0284C7)),
      ),
    );
  }

  Widget _buildHeroOmzetCard(num omzet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.trending_up_rounded, color: Color(0xFF0284C7), size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'TOTAL OMZET PERIODE INI',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatCurrency(omzet),
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4), // Green 50
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                SizedBox(width: 4),
                Text(
                  "Penjualan Kotor Akumulatif",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardBody() {
    final data = _dashboardData!;
    final pemasukan = data['pemasukan'] ?? {};
    final totalKas = (data['kas_besar'] ?? 0) + (data['kas_kasir'] ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SHORTCUT KE TAB MONITORING SHIFT & BUKTI SETORAN
        _buildShiftShortcutCard(),

        const SizedBox(height: 24),

        // SECTION 1: POSISI KAS RIIL
        _buildSectionTitle(
          title: "Posisi Kas Depot",
          subtitle: "Uang fisik dan saldo kas saat ini",
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKasCard(
                title: "Kas Besar (Bank/Utama)",
                amount: data['kas_besar'] ?? 0,
                icon: Icons.account_balance_rounded,
                badgeColor: const Color(0xFF4F46E5), // Indigo 600
                bgColor: const Color(0xFFEEF2FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKasCard(
                title: "Kas Kasir (Uang Laci)",
                amount: data['kas_kasir'] ?? 0,
                icon: Icons.point_of_sale_rounded,
                badgeColor: const Color(0xFFEA580C), // Orange 600
                bgColor: const Color(0xFFFFEDD5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Total Kas Tunai Riil Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF86EFAC)), // Green 300
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16A34A).withValues(alpha: 0.06),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7), // Green 100
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Uang Kas Riil",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF14532D),
                        ),
                      ),
                      Text(
                        "Gabungan Kas Besar & Laci",
                        style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                _formatCurrency(totalKas),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF15803D),
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // SECTION 2: METODE PEMBAYARAN
        _buildSectionTitle(
          title: "Rincian Metode Pembayaran",
          subtitle: "Distribusi pemasukan berdasarkan cara bayar pelanggan",
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withValues(alpha: 0.06),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildIncomeRow(
                title: "Tunai (Cash)",
                amount: pemasukan['tunai'] ?? 0,
                icon: Icons.payments_rounded,
                badgeColor: const Color(0xFF16A34A),
                bgColor: const Color(0xFFDCFCE7),
              ),
              const Divider(height: 1, indent: 68, endIndent: 20),
              _buildIncomeRow(
                title: "Transfer Bank",
                amount: pemasukan['transfer'] ?? 0,
                icon: Icons.account_balance_rounded,
                badgeColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
              ),
              const Divider(height: 1, indent: 68, endIndent: 20),
              _buildIncomeRow(
                title: "QRIS / E-Wallet",
                amount: pemasukan['qris'] ?? 0,
                icon: Icons.qr_code_2_rounded,
                badgeColor: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFEDE9FE),
              ),
              const Divider(height: 1, indent: 68, endIndent: 20),
              _buildIncomeRow(
                title: "Langganan / Corporate",
                amount: pemasukan['corporate'] ?? 0,
                icon: Icons.business_rounded,
                badgeColor: const Color(0xFFEA580C),
                bgColor: const Color(0xFFFFEDD5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "TOTAL PEMASUKAN",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _formatCurrency(pemasukan['total'] ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0284C7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShiftShortcutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBAE6FD)), // Sky 200
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF0284C7), size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Log Shift & Bukti Setoran Kasir",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Cek kehadiran shift kasir & foto setoran laci",
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (widget.onNavigateToShiftTab != null) {
                widget.onNavigateToShiftTab!();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OwnerShiftMonitoringScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            child: const Text("Buka"),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildKasCard({
    required String title,
    required num amount,
    required IconData icon,
    required Color badgeColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: badgeColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: badgeColor,
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeRow({
    required String title,
    required num amount,
    required IconData icon,
    required Color badgeColor,
    required Color bgColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: badgeColor, size: 20),
          ),
          const SizedBox(width: 14),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: Color(0xFF1E293B),
            ),
          ),
          const Spacer(),
          Text(
            _formatCurrency(amount),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}