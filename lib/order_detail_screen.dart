import 'package:flutter/material.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'printer_service.dart';
import 'main_screen.dart';
import 'widgets/custom_dialogs.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderNumber;

  const OrderDetailScreen({super.key, required this.orderNumber});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _orderDetail;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
  }

  Future<void> _fetchOrderDetail() async {
    setState(() => _isLoading = true);
    final detail = await _apiService.getOrderDetail(widget.orderNumber);
    print("DEBUG CASHIER DETAIL RESPONSE: $detail"); // Cek field timestamp
    if (mounted) {
      setState(() {
        _orderDetail = detail;
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(dynamic amount) {
    num value = 0;
    if (amount is num) value = amount;
    else if (amount is String) value = num.tryParse(amount) ?? 0;
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  num _parseNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
    return 0;
  }

  String _formatDate(dynamic dateString) {
      if (dateString == null || dateString is! String) return '-';
      try {
          return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(dateString).toLocal());
      } catch (e) {
          return dateString;
      }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('YA, Lanjut')),
        ],
      ),
    ) ?? false;
  }
  
  Future<void> _launchUrl(String url) async {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuka link navigasi.')));
      }
  }

  // ACTIONS
  Future<void> _handleMarkAsReady() async {
    if (!await _showConfirmationDialog('Siapkan Pesanan?', 'Status akan berubah jadi READY.')) return;
    
    setState(() => _isProcessing = true);
    try {
        final result = await _apiService.markOrderAsReady(widget.orderNumber);
        
        if (mounted) {
             if (result['success'] == true) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Berhasil!'), backgroundColor: Colors.green));
                 _fetchOrderDetail();
                 // AUTO PRINT RECEIPT
                 if (_orderDetail != null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mencetak Struk Transaksi...')));
                      await PrinterService().printReceipt(_orderDetail!);
                 }
             } else {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Gagal mengubah status'), backgroundColor: Colors.red));
             }
        }
    } catch (e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
        if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleComplete() async {
    if (!await _showConfirmationDialog('Selesaikan Order', 'Yakin ingin menyelesaikan order ini?')) return;
    setState(() => _isProcessing = true);
    final success = await _apiService.completeOrderManual(widget.orderNumber);
    setState(() => _isProcessing = false);
    
    if (mounted && success) {
        // Refresh data first to get latest status/time if needed, or just print current detail
        await _fetchOrderDetail(); 
        
        // AUTO PRINT RECEIPT
        if (_orderDetail != null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mencetak Struk Transaksi...')));
            await PrinterService().printReceipt(_orderDetail!);
        }
    } 
  }

  Future<void> _handleCancel() async {
    final reasons = [
      'Salah input barang / jumlah',
      'Pelanggan membatalkan pesanan',
      'Uang pembayaran kurang / tidak jadi bayar',
      'Pesanan dobel / duplikat',
      'Lainnya',
    ];

    String selectedReason = reasons.first;
    final TextEditingController otherReasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isComplete = (_orderDetail?['status'] ?? '').toString().toUpperCase() == 'COMPLETE';
          final paymentType = (_orderDetail?['payment_type'] ?? '').toString().toUpperCase();
          final totalAmount = _formatCurrency(_orderDetail?['total_amount'] ?? 0);

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Batalkan Pesanan (Void)',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Stok & uang laci akan disesuaikan',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Warning Notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Text(
                              isComplete ? 'Pesanan Sudah Selesai (COMPLETE)' : 'Konfirmasi Pembatalan',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          paymentType == 'TUNAI'
                              ? '• Saldo laci kasir akan otomatis DIPOTONG $totalAmount (refund kasir).\n• Semua stok galon/barang akan DIKEMBALIKAN ke sistem.'
                              : '• Semua stok galon/barang akan otomatis DIKEMBALIKAN ke sistem.',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Pilih Alasan Pembatalan:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),

                  // Dropdown / Radio alasan
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedReason,
                        items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedReason = val);
                          }
                        },
                      ),
                    ),
                  ),

                  if (selectedReason == 'Lainnya') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: otherReasonCtrl,
                      decoration: InputDecoration(
                        hintText: 'Tulis alasan pembatalan...',
                        hintStyle: const TextStyle(fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Kembali'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Batalkan Nota', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (confirmed != true) return;

    final finalReason = selectedReason == 'Lainnya' && otherReasonCtrl.text.trim().isNotEmpty
        ? otherReasonCtrl.text.trim()
        : selectedReason;

    setState(() => _isProcessing = true);
    final result = await _apiService.cancelOrder(widget.orderNumber, reason: finalReason);
    setState(() => _isProcessing = false);

    if (!mounted) return;

    if (result['success'] == true) {
      await showAppSuccessDialog(
        context: context,
        title: 'Pesanan Dibatalkan',
        message: result['message'] ?? 'Pesanan berhasil dibatalkan.',
        hint: 'Stok barang telah dikembalikan ke gudang dan saldo laci kasir telah disesuaikan.',
        onConfirm: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen(initialIndex: 2)),
            (route) => false,
          );
        },
      );
    } else {
      await showAppErrorDialog(
        context: context,
        title: 'Gagal Membatalkan',
        message: result['message'] ?? 'Terjadi kesalahan saat membatalkan pesanan.',
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETE': return Colors.green;
      case 'READY': return Colors.orange;
      case 'ON_DELIVERY': return Colors.blue;
      case 'CANCELLED': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'COMPLETE': return 'SELESAI';
      case 'READY': return 'SIAP DIAMBIL / ANTAR';
      case 'ON_DELIVERY': return 'SEDANG DIANTAR';
      case 'CANCELLED': return 'DIBATALKAN';
      case 'PREPARED': return 'DIPROSES DAPUR';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_orderDetail == null) return const Scaffold(body: Center(child: Text('Data tidak ditemukan.')));

    final detail = _orderDetail!;
    final currentStatus = (detail['status'] as String? ?? 'UNKNOWN').toUpperCase();
    final statusColor = _getStatusColor(currentStatus);
    final statusText = _getStatusText(currentStatus);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Order #${widget.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      body: Column(
        children: [
          // STATUS BANNER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: statusColor,
            alignment: Alignment.center,
            child: Text(
              statusText,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // RECEIPT CARD
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HEADER
                          Center(
                            child: Column(
                              children: [
                                const Icon(Icons.receipt_long, color: Colors.grey, size: 32),
                                const SizedBox(height: 8),
                                Text(_formatDate(detail['created_at']), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(detail['payment_type'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                          const Divider(height: 32),

                          // CUSTOMER INFO
                          const Text('INFORMASI PELANGGAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Icon(Icons.person, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Expanded(child: Text(detail['customer']['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                                Icon(Icons.phone, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(detail['customer']['phone'] ?? '-'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Icon(Icons.location_on, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Expanded(child: Text(detail['customer']['address'] ?? '-')),
                            ],
                          ),
                          
                          // GMAPS BUTTON
                          if (detail['customer']['gmaps_url'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                        onPressed: () => _launchUrl(detail['customer']['gmaps_url']),
                                        icon: const Icon(Icons.map, size: 16),
                                        label: const Text('Buka Google Maps'),
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.blue.shade700),
                                    )
                                ),
                              ),

                          const Divider(height: 32),

                          // NOTES
                          if (detail['notes'] != null && detail['notes'].toString().isNotEmpty && detail['notes'] != '-') ...[
                             const Text('CATATAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                             const SizedBox(height: 8),
                             Container(
                               width: double.infinity,
                               padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(color: Colors.yellow.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.yellow.shade200)),
                               child: Text(detail['notes'] ?? '', style: TextStyle(color: Colors.orange.shade900, fontStyle: FontStyle.italic)),
                             ),
                             const Divider(height: 32),
                          ],

                          // ITEMS
                          const Text('ITEM PESANAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 12),
                          ...(detail['items'] as List<dynamic>? ?? []).map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('${item['quantity']} x ${_formatCurrency(item['price'])}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Text(_formatCurrency(item['subtotal']), style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }).toList(),

                          const Divider(height: 24),
                          
                          // TOTALS
                          _buildSummaryRow('Subtotal', _parseNum(detail['subtotal'])),
                          _buildSummaryRow('Ongkir', _parseNum(detail['delivery_fee'])),
                          if (_parseNum(detail['additional_fee']) > 0)
                            _buildSummaryRow('Biaya Lain', _parseNum(detail['additional_fee'])),
                          
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL TAGIHAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(_formatCurrency(detail['total_amount']), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: statusColor)),
                            ],
                          ),
                          
                          if (currentStatus == 'COMPLETE') ...[
                             const SizedBox(height: 12),
                             const Divider(height: 1), 
                             const SizedBox(height: 12),
                             _buildCompletionDuration(detail, isDarkText: true),
                          ]
                        ],
                      ),
                    ),
                  ),

                  // DELIVERY PROOF
                  if (detail['delivery_proof'] != null)
                    _buildProofSection(detail['delivery_proof']),

                  const SizedBox(height: 100), // Space for bottom bar
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(detail, currentStatus),
    );
  }

  Widget _buildSummaryRow(String label, num amount) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  Text(label, style: const TextStyle(color: Colors.grey)),
                  Text(_formatCurrency(amount), style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
          ),
      );
  }

  Widget _buildProofSection(Map<String, dynamic> proof) {
      final imageUrl = proof['image_url'] as String? ?? '';
      return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200)
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  const Text('BUKTI PENGANTARAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                  const SizedBox(height: 8),
                  GestureDetector(
                      onTap: () => _showFullImage(imageUrl),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                              imageUrl, 
                              height: 150, 
                              width: double.infinity, 
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                  height: 150, 
                                  color: Colors.grey.shade200, 
                                  child: const Center(child: Text('Gagal memuat gambar bukti'))
                              ),
                          ),
                      ),
                  ),
                  const SizedBox(height: 8),
                  Text("Catatan: ${proof['notes'] ?? '-'}", style: const TextStyle(fontSize: 12)),
                  Text("Diupload: ${proof['uploaded_at'] ?? '-'} oleh ${proof['uploaded_by'] ?? '-'}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
          ),
      );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context, 
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            url,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 300,
                color: Colors.white,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text('Gagal memuat gambar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('URL tidak valid atau file hilang', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(Map<String, dynamic> detail, String status) {
      bool showReady = ['DRAFT', 'PREPARED', 'PENDING', 'NEW', 'PAID'].contains(status);
      bool showComplete = ['READY', 'ON_DELIVERY'].contains(status);

      // --- ATURAN KEAMANAN PEMBATALAN: Maksimal 60 Menit sejak dibuat ---
      bool isUnder60Minutes = true;
      final createdAt = _parseDate(detail['created_at']);
      if (createdAt != null) {
        final elapsedMinutes = DateTime.now().difference(createdAt).inMinutes;
        if (elapsedMinutes > 60) {
          isUnder60Minutes = false;
        }
      }

      // Bisa cancel jika belum CANCELLED dan masih dalam batas aman 60 menit
      bool showCancel = status != 'CANCELLED' && (detail['can_cancel'] ?? isUnder60Minutes);

      if (!showReady && !showComplete && !showCancel) return const SizedBox.shrink();

      return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]
          ),
          child: SafeArea(
              child: Row(
                  children: [
                      if (showCancel)
                          Expanded(
                              child: OutlinedButton.icon(
                                  onPressed: _isProcessing ? null : _handleCancel,
                                  style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: BorderSide(color: Colors.red.shade300),
                                      foregroundColor: Colors.red.shade700,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.cancel_outlined, size: 18),
                                  label: const Text('BATALKAN NOTA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                          ),
                      
                      if (showCancel && (showComplete || showReady)) const SizedBox(width: 12),

                      if (showReady)
                          Expanded(
                              child: ElevatedButton(
                                  onPressed: _isProcessing ? null : _handleMarkAsReady,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      elevation: 0
                                  ),
                                  child: const Text('SIAP DIANTAR', style: TextStyle(fontWeight: FontWeight.bold)),
                              )
                          ),

                      if (showComplete)
                          Expanded(
                              child: ElevatedButton(
                                  onPressed: _isProcessing ? null : _handleComplete,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      elevation: 0
                                  ),
                                  child: const Text('SELESAIKAN ORDER', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              )
                          ),
                  ],
              ),
          ),
      );
  }
  Widget _buildCompletionDuration(Map<String, dynamic> detail, {bool isDarkText = false}) {
      print("DEBUG DURATION [START]");
      print("DEBUG KEYS: ${detail.keys.toList()}");
      
      // 1. Cari End Time: Priority completed_time (DB) -> completed_at -> updated_at -> delivery_proof.uploaded_at
      DateTime? completedAt = _parseDate(detail['completed_time']) ?? 
                              _parseDate(detail['completed_at']) ?? 
                              _parseDate(detail['updated_at']);
      
      if (completedAt == null && detail['delivery_proof'] != null) {
          completedAt = _parseDate(detail['delivery_proof']['uploaded_at']);
      }

      // 2. Cari Start Time
      // User request: Total Duration = completed - created
      DateTime? startTime = _parseDate(detail['created_at']);
      String label = "Total Durasi";

      // Jika null, coba fallback ke field lain
      if (startTime == null) {
         if (detail['delivery_time'] != null) {
            startTime = _parseDate(detail['delivery_time']);
            label = "Durasi Pengantaran";
         } else if (detail['ready_time'] != null) {
             startTime = _parseDate(detail['ready_time']);
             label = "Durasi Sejak Siap";
         }
      }

      print("DEBUG DURATION: Start=$startTime End=$completedAt");

      if (completedAt != null && startTime != null) {
          Duration diff = completedAt.difference(startTime);
          // Handle negative duration
          if (diff.isNegative) diff = Duration.zero;

          String durationText = "";
          if (diff.inHours > 0) durationText += "${diff.inHours} jam ";
          durationText += "${diff.inMinutes % 60} menit";
          if (durationText.trim().isEmpty) durationText = "< 1 menit";

          return Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(
                  durationText,
                  style: TextStyle(
                    color: isDarkText ? Colors.black87 : Colors.white, 
                    fontSize: 14, 
                    fontWeight: FontWeight.bold
                  ),
                ),
             ],
          );
      }
      return const SizedBox.shrink();
  }


  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr == '-' || dateStr.isEmpty) return null;
    try {
      // 1. Try ISO (e.g. 2026-01-14T08:12:47.000000Z)
      // Note: tryParse might fail for "2026-01-14 08:12:47" on some platforms/versions
      final iso = DateTime.tryParse(dateStr);
      if (iso != null) return iso;
    } catch (_) {}

    try {
       // 2. Try SQL Format "2026-01-14 08:12:47" explicitly
       return DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateStr);
    } catch (_) {}

    try {
       // 3. Try "16 Jan 2026 07:19"
       return DateFormat('d MMM y HH:mm').parse(dateStr);
    } catch (_) {}

    try {
       // 4. Try "16/01/2026 07:19"
       return DateFormat('dd/MM/yyyy HH:mm').parse(dateStr);
    } catch (_) {}

    try {
       // 5. Try "16/1/2026 7:19"
       return DateFormat('d/M/y H:i').parse(dateStr);
    } catch (_) {}

    return null;
  }
}