import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'role_based_router.dart';
import 'order_history_screen.dart';
import 'widgets/cashier_reminder_dialog.dart';

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

    // 1. Cek apakah ada pesanan hari ini yang belum selesai
    try {
      final ordersRes = await _apiService.getOrderHistory();
      if (ordersRes != null && ordersRes['data'] is List) {
        final List<dynamic> list = ordersRes['data'];
        final unfinished = list.where((o) {
          if (o is! Map<String, dynamic>) return false;
          final st = (o['status'] ?? '').toString().toUpperCase();
          return st != 'COMPLETE' && st != 'DONE' && st != 'CANCELLED' && st != 'DELIVERED';
        }).toList();

        if (unfinished.isNotEmpty && mounted) {
          final reviewOrders = await showUnfinishedOrdersWarningDialog(
            context: context,
            unfinishedOrders: unfinished.cast<Map<String, dynamic>>(),
          );

          if (reviewOrders == true && mounted) {
            // Pengguna memilih untuk memeriksa pesanan terlebih dahulu
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
            );
            if (mounted) _fetchShiftData();
          }
          // WAJIB RETURN: Tutup shift digembok keras sampai seluruh pesanan berstatus COMPLETE atau CANCELLED
          return;
        }
      }
    } catch (_) {}

    if (!mounted) return;

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
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const RoleBasedRouter()),
                    (route) => false,
                  );
                },
                child: const Text("TETAP MASUK", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
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
                child: const Text("GANTI KASIR (LOGOUT)"),
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
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: difference == 0
                        ? const Color(0xFFF0FDF4)
                        : (difference > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: difference == 0
                          ? const Color(0xFF86EFAC)
                          : (difference > 0 ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            difference == 0
                                ? Icons.check_circle_rounded
                                : (difference > 0 ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded),
                            color: difference == 0
                                ? const Color(0xFF16A34A)
                                : (difference > 0 ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              difference == 0
                                  ? "Uang Fisik PAS! Tidak ada selisih."
                                  : (difference > 0
                                      ? "Uang Fisik LEBIH: +${_formatCurrency(difference)}"
                                      : "Uang Fisik KURANG (MINUS): ${_formatCurrency(difference)}"),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: difference == 0
                                    ? const Color(0xFF15803D)
                                    : (difference > 0 ? const Color(0xFFB45309) : const Color(0xFFB91C1C)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      if (difference == 0)
                        const Row(
                          children: [
                            Icon(Icons.thumb_up_alt_outlined, size: 14, color: Color(0xFF15803D)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Uang di laci 100% cocok dengan pembukuan sistem. Siap serah terima shift!",
                                style: TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        )
                      else if (difference < 0) ...[
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                            SizedBox(width: 6),
                            Text(
                              "Kemungkinan Penyebab Uang Fisik Kurang:",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "1. Lupa catat belanja kasir (beli bensin, es batu, galon, lakban, dll).\n"
                          "2. Salah memberi kembalian lebih ke pembeli.\n"
                          "3. Ada nota kasir terinput TUNAI padahal pembeli belum bayar / utang.\n"
                          "4. Ada uang kertas/koin terselip di bawah laci kasir.",
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D), height: 1.45),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "👉 Tulis alasannya di kolom 'Catatan Kasir' di bawah jika uang memang tidak ketemu.",
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFFB91C1C)),
                        ),
                      ] else ...[
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, size: 15, color: Color(0xFFD97706)),
                            SizedBox(width: 6),
                            Text(
                              "Kemungkinan Penyebab Uang Fisik Lebih:",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "1. Ada penjualan tunai yang belum sempat diinput nota di aplikasi.\n"
                          "2. Pembeli tidak mengambil uang kembalian (tip kasir masuk laci).\n"
                          "3. Salah memberi kembalian kurang ke pembeli.\n"
                          "4. Uang pribadi kasir tidak sengaja tercampur ke dalam laci.",
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.45),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "👉 Tulis keterangannya di kolom 'Catatan Kasir' di bawah.",
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFFB45309)),
                        ),
                      ],
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
