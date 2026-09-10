import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

class OwnerShiftMonitoringScreen extends StatefulWidget {
  const OwnerShiftMonitoringScreen({super.key});

  @override
  State<OwnerShiftMonitoringScreen> createState() => _OwnerShiftMonitoringScreenState();
}

class _OwnerShiftMonitoringScreenState extends State<OwnerShiftMonitoringScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  List<dynamic> _shiftList = [];
  List<dynamic> _depositList = [];

  bool _isLoadingShifts = true;
  bool _isLoadingDeposits = true;
  DateTime? _filterDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAll() {
    _loadShifts();
    _loadDeposits();
  }

  Future<void> _loadShifts() async {
    setState(() => _isLoadingShifts = true);
    final String? dateStr = _filterDate != null ? DateFormat('yyyy-MM-dd').format(_filterDate!) : null;
    final data = await _apiService.getShiftHistory(date: dateStr);
    if (mounted) {
      setState(() {
        _shiftList = data;
        _isLoadingShifts = false;
      });
    }
  }

  Future<void> _loadDeposits() async {
    setState(() => _isLoadingDeposits = true);
    final String? dateStr = _filterDate != null ? DateFormat('yyyy-MM-dd').format(_filterDate!) : null;
    final data = await _apiService.getDepositHistory(date: dateStr);
    if (mounted) {
      setState(() {
        _depositList = data;
        _isLoadingDeposits = false;
      });
    }
  }

  Future<void> _pickFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
      _loadAll();
    }
  }

  void _resetFilterDate() {
    setState(() => _filterDate = null);
    _loadAll();
  }

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  void _showImagePreview(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto bukti tidak tersedia.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 300,
                      color: Colors.black45,
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.white,
                      child: const Center(child: Text("Gagal memuat foto bukti.")),
                    );
                  },
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Monitoring Shift & Setoran', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade900,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue.shade900,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Riwayat Shift Kasir", icon: Icon(Icons.people_outline)),
            Tab(text: "Setoran Kas Besar", icon: Icon(Icons.photo_camera_outlined)),
          ],
        ),
      ),
      body: Column(
        children: [
          // FILTER TANGGAL
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_filterDate != null ? DateFormat('dd MMM yyyy').format(_filterDate!) : 'Semua Tanggal'),
                  onPressed: _pickFilterDate,
                ),
                if (_filterDate != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20, color: Colors.red),
                    onPressed: _resetFilterDate,
                    tooltip: "Reset Filter",
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildShiftsTab(),
                _buildDepositsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftsTab() {
    if (_isLoadingShifts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_shiftList.isEmpty) {
      return const Center(
        child: Text("Belum ada riwayat shift untuk tanggal ini.", style: TextStyle(color: Colors.grey)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadShifts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _shiftList.length,
        itemBuilder: (context, index) {
          final s = _shiftList[index];
          final bool isOpen = s['status'] == 'OPEN';
          final int diff = (s['difference'] ?? 0) as int;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isOpen ? Colors.green.shade100 : Colors.blue.shade100,
                            child: Icon(Icons.person, color: isOpen ? Colors.green.shade800 : Colors.blue.shade800, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['cashier_name'] ?? 'Kasir', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(
                                "${s['start_time']} s/d ${s['end_time']}",
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOpen ? Colors.green.shade50 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isOpen ? "SEDANG AKTIF" : "DITUTUP",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isOpen ? Colors.green.shade800 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildShiftInfoRow("Modal Awal", _formatCurrency(s['starting_cash'] ?? 0)),
                  _buildShiftInfoRow("Penjualan Tunai", "+${_formatCurrency(s['cash_sales'] ?? 0)}", color: Colors.green.shade800),
                  _buildShiftInfoRow("Pengeluaran Laci", "-${_formatCurrency(s['cash_expenses'] ?? 0)}", color: Colors.red.shade700),
                  _buildShiftInfoRow("Setor ke Kas Besar", "-${_formatCurrency(s['cash_deposited'] ?? 0)}", color: Colors.orange.shade900),
                  const Divider(height: 16),
                  _buildShiftInfoRow("Uang Sistem", _formatCurrency(s['expected_cash'] ?? 0), isBold: true),
                  if (!isOpen && s['actual_cash'] != null) ...[
                    _buildShiftInfoRow("Uang Fisik Dihitung", _formatCurrency(s['actual_cash']), isBold: true, color: Colors.blue.shade900),
                    _buildShiftInfoRow(
                      "Selisih Uang Fisik",
                      diff == 0
                          ? "Pas (Rp 0)"
                          : (diff > 0 ? "+${_formatCurrency(diff)} (Lebih)" : "${_formatCurrency(diff)} (Kurang)"),
                      isBold: true,
                      color: diff == 0 ? Colors.green : (diff > 0 ? Colors.orange.shade800 : Colors.red),
                    ),
                  ],
                  if (s['notes'] != null && s['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Text("Catatan: ${s['notes']}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShiftInfoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isBold ? Colors.black87 : Colors.grey.shade700, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildDepositsTab() {
    if (_isLoadingDeposits) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_depositList.isEmpty) {
      return const Center(
        child: Text("Belum ada riwayat setoran kas besar untuk tanggal ini.", style: TextStyle(color: Colors.grey)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDeposits,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _depositList.length,
        itemBuilder: (context, index) {
          final d = _depositList[index];
          final String? photoUrl = d['proof_image_url'];

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // THUMBNAIL FOTO BUKTI
                  GestureDetector(
                    onTap: () => _showImagePreview(photoUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey.shade200,
                        child: photoUrl != null && photoUrl.isNotEmpty
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(photoUrl, fit: BoxFit.cover),
                                  Container(
                                    color: Colors.black26,
                                    child: const Center(child: Icon(Icons.zoom_in, color: Colors.white, size: 24)),
                                  ),
                                ],
                              )
                            : const Center(child: Icon(Icons.no_photography, color: Colors.grey)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // DETAIL SETORAN
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatCurrency(d['amount'] ?? 0),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.green.shade800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Penyetor: ${d['on_behalf_of_name'] ?? d['recorded_by_name']}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          d['date'] ?? '-',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        ),
                        if (d['description'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            d['description'],
                            style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ICON LIHAT FOTO
                  if (photoUrl != null && photoUrl.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.indigo),
                      onPressed: () => _showImagePreview(photoUrl),
                      tooltip: "Lihat Foto Bukti",
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
