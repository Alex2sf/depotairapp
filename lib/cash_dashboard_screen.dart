import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

class CashDashboardScreen extends StatefulWidget {
  const CashDashboardScreen({super.key});

  @override
  State<CashDashboardScreen> createState() => _CashDashboardScreenState();
}

class _CashDashboardScreenState extends State<CashDashboardScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _todayTopProducts = [];
  List<dynamic> _todayRiwayat = [];
  Map<String, dynamic> _todaySaldoData = {}; 

  Map<String, dynamic> _pemasukan = {}; 
  Map<String, dynamic>? _userProfile; // Add profile storage
  
  bool _isLoadingAll = true;
  bool _isLoadingFilter = false;

  DateTime? _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoadingAll = true);
    final profile = await _apiService.getProfile(); // Fetch profile
    final result = await _apiService.getCashDashboard();

    if (mounted) {
      if (result != null && result['success'] == true) {
        setState(() {
          _todayTopProducts = result['top_products'] ?? [];
          _todayRiwayat = result['riwayat'] ?? [];
          _todaySaldoData = result; 
          _pemasukan = result['pemasukan'] ?? {}; 
          _userProfile = profile; // Save profile
          _isLoadingAll = false;
        });
      } else {
        setState(() => _isLoadingAll = false);
      }
    }
  }

  Future<void> _updatePemasukanOnly() async {
    setState(() => _isLoadingFilter = true);

    final String? start = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null;
    final String? end = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;

    final result = await _apiService.getCashDashboard(startDate: start, endDate: end);

    if (mounted) {
      if (result != null && result['success'] == true) {
        setState(() {
          _pemasukan = result['pemasukan'] ?? {};
          _isLoadingFilter = false;
        });
      } else {
        setState(() => _isLoadingFilter = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && picked.isAfter(_endDate!)) _endDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _updatePemasukanOnly();
    }
  }

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  String _formatDateShort(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Dashboard Kas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _fetchInitialData, 
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchInitialData,
        child: _isLoadingAll
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FILTER TANGGAL
                    _buildDateFilter(),
                    const SizedBox(height: 20),
                    
                    if (_isLoadingFilter) 
                       const LinearProgressIndicator(),

                    // PEMASUKAN CARD (GRADIENT HIJAU)
                    _buildPemasukanSection(),
                    const SizedBox(height: 24),

                    // SALDO KAS CARD (GRADIENT BIRU)
                    _buildSaldoSection(),
                    const SizedBox(height: 30),
                    
                    // RIWAYAT HEADER
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            const Text('Transaksi Hari Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                                child: Text('Realtime', style: TextStyle(color: Colors.blue.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                            )
                        ],  
                    ),
                    const SizedBox(height: 16),
                    _buildHistoryList(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)
        ),
        child: Row(
            children: [
                Expanded(
                    child: InkWell(
                        onTap: () => _selectDate(context, true),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text('DARI TANGGAL', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Row(
                                        children: [
                                            Icon(Icons.calendar_today, size: 14, color: Colors.blue.shade700),
                                            const SizedBox(width: 8),
                                            Text(_formatDateShort(_startDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                    )
                                ],
                            ),
                        ),
                    ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                Expanded(
                    child: InkWell(
                        onTap: () => _selectDate(context, false),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text('SAMPAI TANGGAL', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Row(
                                        children: [
                                            Icon(Icons.calendar_today, size: 14, color: Colors.blue.shade700),
                                            const SizedBox(width: 8),
                                            Text(_formatDateShort(_endDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                    )
                                ],
                            ),
                        ),
                    ),
                ),
            ],
        ),
    );
  }

  Widget _buildPemasukanSection() {
    final int tunai = _pemasukan['TUNAI'] ?? 0;
    final int qris = _pemasukan['QRIS'] ?? 0;
    final int transfer = _pemasukan['TRANSFER'] ?? 0;
    final int corporate = _pemasukan['CORPORATE'] ?? 0;
    final int totalOmzet = tunai + qris + transfer + corporate;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.green.shade800, Colors.green.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
            BoxShadow(color: Colors.green.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 10))
        ]
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Text('Total Pemasukan', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                _formatCurrency(totalOmzet), 
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)
            ),
            const SizedBox(height: 24),
            Row(
                children: [
                    Expanded(child: _buildMiniStat('Tunai', tunai, Colors.white.withOpacity(0.15))),
                    const SizedBox(width: 4),
                    Expanded(child: _buildMiniStat('QRIS', qris, Colors.white.withOpacity(0.15))),
                    const SizedBox(width: 4),
                    Expanded(child: _buildMiniStat('Transfer', transfer, Colors.white.withOpacity(0.15))),
                    const SizedBox(width: 4),
                    Expanded(child: _buildMiniStat('Corp', corporate, Colors.white.withOpacity(0.15))),
                ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, dynamic amount, Color bg) {
      return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12)
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text(label.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_formatCurrency(amount).replaceAll('Rp ', ''), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))
              ],
          ),
      );
  }

  Widget _buildSaldoSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.blue.shade900, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
            BoxShadow(color: Colors.blue.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 10))
        ]
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Text('Total Saldo Fisik', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatCurrency(_todaySaldoData['total_kas'] ?? 0), 
              style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 24),
            Row(
                children: [
                    Expanded(child: _buildMiniStat('Kasir', _todaySaldoData['kas_kasir'], Colors.white.withOpacity(0.15))),
                    const SizedBox(width: 10),
                    // Hanya Tampilkan Kas Besar jika User adalah Owner
                    if (_userProfile != null && (_userProfile!['role'] == 'owner' || _userProfile!['role'] == 'super_admin'))
                       Expanded(child: _buildMiniStat('Kas Besar', _todaySaldoData['kas_besar'], Colors.white.withOpacity(0.15)))
                    else
                       const Spacer(), // Placeholder biar gak jelek layoutnya kalau kosong
                ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_todayRiwayat.isEmpty) {
      return Center(
          child: Column(
              children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('Belum ada transaksi hari ini.', style: TextStyle(color: Colors.grey.shade400)),
              ],
          )
      );
    }
    return Column(
      children: _todayRiwayat.map((t) {
          final isMasuk = t['tipe'] == 'Masuk';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                ]
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: isMasuk ? Colors.green.shade50 : Colors.red.shade50,
                    shape: BoxShape.circle
                ),
                child: Icon(
                    isMasuk ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isMasuk ? Colors.green : Colors.red,
                    size: 20,
                ),
              ),
              title: Text(t['keterangan'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                    children: [
                        Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(t['waktu'], style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(width: 8),
                        Icon(Icons.person_outline, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(t['oleh'], style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                ),
              ),
              trailing: Text(
                _formatCurrency(t['jumlah'] ?? 0),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isMasuk ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          );
      }).toList(),
    );
  }
}