import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'role_based_router.dart';

class CloseShiftScreen extends StatefulWidget {
  const CloseShiftScreen({super.key});

  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _actualCashController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isFetching = true;

  Map<String, dynamic>? _shiftData;
  Map<String, dynamic>? _previousShiftInfo;

  @override
  void initState() {
    super.initState();
    _fetchShiftData();
  }

  @override
  void dispose() {
    _actualCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchShiftData() async {
    setState(() => _isFetching = true);

    final result = await _apiService.getCurrentShift();
    if (mounted) {
      if (result != null && result['success'] == true) {
        _shiftData = result['shift'];
        _previousShiftInfo = result['previous_shift_info'];
      }
      setState(() => _isFetching = false);
    }
  }

  void _formatInputCurrency(String value) {
    if (value.isEmpty) {
      setState(() {});
      return;
    }
    String clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    double number = double.parse(clean);
    String formatted = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(number).trim();

    _actualCashController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {});
  }

  int _getEnteredActualCash() {
    final clean = _actualCashController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? 0;
  }

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  Future<void> _submitCloseShift() async {
    if (!_formKey.currentState!.validate()) return;

    final actualCash = _getEnteredActualCash();
    final expectedCash = (_shiftData?['expected_cash'] ?? 0) as int;
    final diff = actualCash - expectedCash;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text("Konfirmasi Tutup Shift"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pastikan uang fisik di laci sudah dihitung dengan benar."),
            const SizedBox(height: 16),
            _buildDialogRow("Uang Menurut Sistem:", _formatCurrency(expectedCash), Colors.black87),
            _buildDialogRow("Uang Fisik Dihitung:", _formatCurrency(actualCash), Colors.blue.shade900),
            _buildDialogRow(
              "Selisih:",
              diff == 0
                  ? "Pas (Rp 0)"
                  : (diff > 0 ? "+${_formatCurrency(diff)} (Lebih)" : "${_formatCurrency(diff)} (Kurang)"),
              diff == 0 ? Colors.green : (diff > 0 ? Colors.orange.shade800 : Colors.red),
            ),
            const SizedBox(height: 12),
            const Text(
              "Setelah ditutup, saldo fisik ini akan menjadi modal awal shift berikutnya.",
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text("Ya, Tutup Shift"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final result = await _apiService.postCloseShift(
      actualCash: actualCash,
      notes: _notesController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text("Shift Berhasil Ditutup"),
              ],
            ),
            content: Text(
              "Terima kasih atas kerja kerasnya! Data serah terima laci telah tersimpan rapi.\n\nSisa uang fisik ${_formatCurrency(actualCash)} aman di laci untuk kasir selanjutnya.",
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _apiService.logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const RoleBasedRouter()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text("SELESAI & LOGOUT"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal: ${result['message'] ?? 'Terjadi kesalahan'}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDialogRow(String label, String val, Color valColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: valColor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetching) {
      return Scaffold(
        appBar: AppBar(title: const Text("Tutup Shift")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final cashierName = _shiftData?['cashier_name'] ?? 'Kasir';
    final startTime = _shiftData?['start_time'] ?? '-';
    final startingCash = (_shiftData?['starting_cash'] ?? 0) as int;
    final cashSales = (_shiftData?['cash_sales'] ?? 0) as int;
    final cashExpenses = (_shiftData?['cash_expenses'] ?? 0) as int;
    final cashDeposited = (_shiftData?['cash_deposited'] ?? 0) as int;
    final expectedCash = (_shiftData?['expected_cash'] ?? 0) as int;

    final enteredActualCash = _getEnteredActualCash();
    final difference = _actualCashController.text.isNotEmpty ? (enteredActualCash - expectedCash) : 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Tutup Shift Kasir", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade700,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cashierName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Shift Aktif Sejak: $startTime",
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                          ),
                          if (_previousShiftInfo != null && _previousShiftInfo!['other_user_name'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Estafet dari: ${_previousShiftInfo!['other_user_name']}",
                              style: TextStyle(color: Colors.blue.shade900, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "RINGKASAN PEMBUKUAN SISTEM",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                    ),
                    const Divider(height: 20),
                    _buildSummaryRow("Modal Awal Laci (+)", _formatCurrency(startingCash), Colors.black87),
                    _buildSummaryRow("Penjualan Tunai (+)", _formatCurrency(cashSales), Colors.green.shade800),
                    _buildSummaryRow("Pengeluaran Kas Laci (-)", _formatCurrency(cashExpenses), Colors.red.shade700),
                    _buildSummaryRow("Setoran ke Kas Besar (-)", _formatCurrency(cashDeposited), Colors.orange.shade900),
                    const Divider(height: 24, thickness: 1.2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total Seharusnya di Laci",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          _formatCurrency(expectedCash),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                "Hitung Uang Fisik di Laci",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text(
                "Keluarkan uang dari laci dan masukkan total rupiah fisik yang ada:",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _actualCashController,
                keyboardType: TextInputType.number,
                onChanged: _formatInputCurrency,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  hintText: '0',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () {
                      String formatted = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(expectedCash).trim();
                      _actualCashController.text = formatted;
                      setState(() {});
                    },
                    tooltip: "Isi sesuai sistem jika uang pas",
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Uang fisik wajib diisi!';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              if (_actualCashController.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: difference == 0
                        ? Colors.green.shade50
                        : (difference > 0 ? Colors.orange.shade50 : Colors.red.shade50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: difference == 0
                          ? Colors.green.shade300
                          : (difference > 0 ? Colors.orange.shade300 : Colors.red.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        difference == 0
                            ? Icons.check_circle
                            : (difference > 0 ? Icons.info : Icons.warning_amber),
                        color: difference == 0
                            ? Colors.green.shade700
                            : (difference > 0 ? Colors.orange.shade800 : Colors.red.shade700),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          difference == 0
                              ? "Uang laci PAS! Tidak ada selisih."
                              : (difference > 0
                                  ? "Uang laci LEBIH: +${_formatCurrency(difference)} (Mungkin ada penjualan belum terinput)"
                                  : "Uang laci KURANG: ${_formatCurrency(difference)}"),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: difference == 0
                                ? Colors.green.shade800
                                : (difference > 0 ? Colors.orange.shade900 : Colors.red.shade800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              const Text("Catatan Kasir (Opsional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "Misal: Uang lebih 10rb karena tip pelanggan / lupa input 1 galon",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitCloseShift,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade900,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "SELESAIKAN & TUTUP SHIFT",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        ],
      ),
    );
  }
}
