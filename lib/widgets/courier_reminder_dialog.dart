import 'package:flutter/material.dart';

enum CourierReminderAction {
  alreadyFinished,
  stillOnTheWay,
}

class CourierReminderDialog extends StatelessWidget {
  final Map<String, dynamic> order;
  final int minutesElapsed;

  const CourierReminderDialog({
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

  @override
  Widget build(BuildContext context) {
    final String orderNumber = order['order_number'] ?? '-';
    final String customerName = order['customer'] ?? '-';
    final String address = order['alamat'] ?? '-';

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
            // Top Badge / Icon Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange.shade200, width: 2),
              ),
              child: Icon(
                Icons.timer_outlined,
                size: 40,
                color: Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 16),

            // Tag Durasi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Text(
                    "Diantar sejak ${_formatDuration(minutesElapsed)} yang lalu",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Judul Pertanyaan
            const Text(
              "Apakah pesanan sudah sampai?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            // Deskripsi Ramah
            Text(
              "Halo! Pesanan #$orderNumber sudah dalam pengantaran lebih dari 1 jam. Apakah barang sudah diterima pelanggan?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Detail Card (Pelanggan & Alamat)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, size: 18, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          customerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                // Tombol Masih di Jalan (Snooze)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, CourierReminderAction.stillOnTheWay),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Masih di Jalan",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Tombol Sudah Selesai (Buka Halaman Detail / Upload Bukti)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, CourierReminderAction.alreadyFinished),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Sudah Selesai",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<CourierReminderAction?> showCourierReminderDialog({
  required BuildContext context,
  required Map<String, dynamic> order,
  required int minutesElapsed,
}) {
  return showDialog<CourierReminderAction>(
    context: context,
    barrierDismissible: false, // Tidak bisa ditutup sembarangan, harus pilih salah satu
    builder: (context) => CourierReminderDialog(
      order: order,
      minutesElapsed: minutesElapsed,
    ),
  );
}
