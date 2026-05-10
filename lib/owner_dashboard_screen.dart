import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

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
            primaryColor: Colors.blue.shade900,
            colorScheme: ColorScheme.light(primary: Colors.blue.shade900),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      }
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchDashboardData();
    }
  }

  String _formatCurrency(num amount) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  String _formatDate(DateTime? date) => date == null ? '-' : DateFormat('dd MMM yyyy').format(date);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: SingleChildScrollView(
                 physics: const AlwaysScrollableScrollPhysics(),
                 padding: const EdgeInsets.all(20),
                 child: _isLoading 
                    ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))
                    : _dashboardData == null
                        ? const Center(child: Text("Gagal memuat data"))
                        : _buildContent(),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 const Text("Dashboard Owner", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                 Text("Pantau performa bisnis Anda", style: TextStyle(color: Colors.blue.shade100, fontSize: 13)),
              ]),
              Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  icon: const Icon(Icons.calendar_month, color: Colors.white),
                  onPressed: _selectDateRange,
                  tooltip: 'Pilih Periode',
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
             onTap: _selectDateRange,
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
               decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(50)),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    const Icon(Icons.date_range, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "${_formatDate(_startDate)}  —  ${_formatDate(_endDate)}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Colors.white)
                 ],
               ),
             ),
          )
        ],
      ),
    );
  }

  Widget _buildContent() {
    final data = _dashboardData!;
    final pemasukan = data['pemasukan'] ?? {};
    final totalKas = (data['kas_besar'] ?? 0) + (data['kas_kasir'] ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HERO CARD: OMZET
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: BorderRadius.circular(20),
             boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('TOTAL OMZET PERIODE INI', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text(_formatCurrency(data['omzet'] ?? 0), style: TextStyle(color: Colors.blue.shade800, fontSize: 32, fontWeight: FontWeight.w800)),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Text("POSISI KAS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
        const SizedBox(height: 12),
        
        Row(
           children: [
              Expanded(child: _buildKasCard("Kas Besar", data['kas_besar'] ?? 0, Colors.indigo)),
              const SizedBox(width: 16),
              Expanded(child: _buildKasCard("Kas Kasir", data['kas_kasir'] ?? 0, Colors.orange)),
           ],
        ),
        const SizedBox(height: 12),
        Container(
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
           decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade100)),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                const Text("Total Uang Tunai (Real)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                Text(_formatCurrency(totalKas), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
             ],
           ),
        ),

        const SizedBox(height: 30),
        const Text("RINCIAN PEMASUKAN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
          child: Column(
            children: [
               _buildIncomeRow("Tunai", pemasukan['tunai'] ?? 0, Icons.money, Colors.green),
               const Divider(height: 1, indent: 60),
               _buildIncomeRow("Transfer", pemasukan['transfer'] ?? 0, Icons.account_balance, Colors.blue),
               const Divider(height: 1, indent: 60),
               _buildIncomeRow("QRIS", pemasukan['qris'] ?? 0, Icons.qr_code, Colors.purple),
               const Divider(height: 1, indent: 60),
               _buildIncomeRow("Corporate", pemasukan['corporate'] ?? 0, Icons.business, Colors.orange),
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      const Text("TOTAL", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
                      Text(_formatCurrency(pemasukan['total'] ?? 0), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 16)),
                   ],
                 ),
               )
            ],
          ),
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildKasCard(String title, num amount, Color color) {
     return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0,4))]),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Row(children: [
               Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.wallet, color: color, size: 16)),
               const SizedBox(width: 8),
               Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
            ]),
            const SizedBox(height: 12),
            Text(_formatCurrency(amount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
         ],
       ),
     );
  }

  Widget _buildIncomeRow(String title, num amount, IconData icon, Color color) {
     return Padding(
       padding: const EdgeInsets.all(16),
       child: Row(
         children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(_formatCurrency(amount), style: const TextStyle(fontWeight: FontWeight.w600)),
         ],
       ),
     );
  }
}