import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum CashierReminderAction {
  completeNow,
  snooze,
  viewDetail,
}

class CashierReminderDialog extends StatelessWidget {
  final Map<String, dynamic> order;
  final int minutesElapsed;

  const CashierReminderDialog({
    super.key,
    required this.order,
    required this.minutesElapsed,
  });

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes menit';
    }
    final int hours = minutes ~/ 60;
    final int remainingMins = minutes % 60;
    if (remainingMins == 0) {
      return '$hours jam';
    }
    return '$hours jam $remainingMins menit';
  }

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final String orderNumber = order['order_number']?.toString() ?? '-';
    final String customerName = order['customer_name']?.toString() ?? order['customer']?.toString() ?? 'Pelanggan';
    final String orderType = (order['order_type'] ?? 'PICKUP').toString().toUpperCase();
    final isDelivery = orderType == 'DELIVERY';
    final num totalAmount = order['total_amount'] ?? 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Badge / Icon Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF), // Blue 50
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE), width: 2), // Blue 200
              ),
              child: const Icon(
                Icons.assignment_late_outlined,
                size: 38,
                color: Color(0xFF1D4ED8), // Blue 700
              ),
            ),
            const SizedBox(height: 14),

            // Tag Durasi Waktu Menggantung
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_rounded, size: 15, color: Colors.amber.shade900),
                  const SizedBox(width: 6),
                  Text(
                    "Menunggu sejak ${_formatDuration(minutesElapsed)} lalu",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Judul Pertanyaan
            const Text(
              "Pesanan Belum Selesai",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),

            // Deskripsi Ramah
            Text(
              "Halo Kasir! Pesanan #$orderNumber belum diselesaikan. Apakah pesanan sudah diambil pelanggan dan pembayaran selesai?",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),

            // Info Card Pesanan
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDelivery ? Icons.motorcycle_rounded : Icons.storefront_rounded,
                            size: 16,
                            color: const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "#$orderNumber",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDelivery ? Colors.orange.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isDelivery ? "Pengantaran" : "Ambil Sendiri",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDelivery ? Colors.orange.shade900 : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          customerName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatCurrency(totalAmount),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                // Tombol Tunda / Nanti
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, CashierReminderAction.snooze),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Nanti Saja",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Tombol Selesaikan Sekarang
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, CashierReminderAction.completeNow),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A), // Green 600
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 18),
                        SizedBox(width: 6),
                        Text(
                          "Sudah Selesai",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Teks Link Detail Pesanan
            GestureDetector(
              onTap: () => Navigator.pop(context, CashierReminderAction.viewDetail),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  "Lihat Detail Pesanan Lengkap",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0284C7),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<CashierReminderAction?> showCashierReminderDialog({
  required BuildContext context,
  required Map<String, dynamic> order,
  required int minutesElapsed,
}) {
  return showDialog<CashierReminderAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) => CashierReminderDialog(
      order: order,
      minutesElapsed: minutesElapsed,
    ),
  );
}

// Dialog Peringatan Tutup Shift jika masih ada pesanan menggantung
class UnfinishedOrdersWarningDialog extends StatelessWidget {
  final List<Map<String, dynamic>> unfinishedOrders;

  const UnfinishedOrdersWarningDialog({
    super.key,
    required this.unfinishedOrders,
  });

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ikon Peringatan Oranye
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.shade200, width: 2),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 36,
                color: Colors.amber.shade800,
              ),
            ),
            const SizedBox(height: 16),

            // Judul
            const Text(
              "Pesanan Belum Selesai!",
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),

            // Pesan
            Text(
              "Terdapat ${unfinishedOrders.length} pesanan yang belum diselesaikan. Sebaiknya selesaikan pesanan terlebih dahulu agar pencatatan kas dan stok saat tutup shift tidak berselisih.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blueGrey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Daftar Pesanan Menggantung (Maksimal 3 tampil scrollable)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: unfinishedOrders.length,
                separatorBuilder: (_, index) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  final ord = unfinishedOrders[i];
                  final ordNum = ord['order_number'] ?? '-';
                  final cust = ord['customer_name'] ?? ord['customer'] ?? 'Pelanggan';
                  final total = ord['total_amount'] ?? 0;
                  final status = (ord['status'] ?? '').toString();

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "#$ordNum • $cust",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "Status: $status",
                                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatCurrency(total),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),

            // Tombol Periksa Pesanan
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true), // true: mau periksa pesanan
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "Periksa & Selesaikan Pesanan",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Tombol Tetap Lanjut Tutup Shift
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false), // false: abaikan & lanjut
                child: Text(
                  "Tetap Lanjut Tutup Shift Saja",
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> showUnfinishedOrdersWarningDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> unfinishedOrders,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => UnfinishedOrdersWarningDialog(
      unfinishedOrders: unfinishedOrders,
    ),
  );
}
