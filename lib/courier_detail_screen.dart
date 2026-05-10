import 'package:flutter/material.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class CourierDetailScreen extends StatefulWidget {
  final String orderNumber;
  const CourierDetailScreen({super.key, required this.orderNumber});

  @override
  State<CourierDetailScreen> createState() => _CourierDetailScreenState();
}

class _CourierDetailScreenState extends State<CourierDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _orderDetail;
  bool _isLoading = true;
  bool _isProcessing = false;
  File? _deliveryImage;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'id';
    _fetchDetail();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    final detail = await _apiService.getCourierOrderDetail(widget.orderNumber);
    print("DEBUG DETAIL RESPONSE: $detail"); // Cek field timestamp
    if (mounted) setState(() { _orderDetail = detail; _isLoading = false; });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuka aplikasi')));
  }

  Future<void> _launchWhatsApp(String? phone) async {
    if (phone == null || phone == '-' || phone.isEmpty) return;
    String number = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (number.startsWith('0')) number = '62${number.substring(1)}';
    final url = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuka WhatsApp')));
  }

  Future<void> _handlePickup() async {
    setState(() => _isProcessing = true);
    final success = await _apiService.pickupOrder(widget.orderNumber);
    setState(() => _isProcessing = false);
    if (mounted) {
      if (success) {
        _fetchDetail();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order diambil! Ayo gas! 🚀')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text('Gagal mengambil order')));
      }
    }
  }

  Future<void> _handleComplete() async {
    if (_deliveryImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text('Foto bukti wajib diisi! 📸')));
      return;
    }
    setState(() => _isProcessing = true);
    final result = await _apiService.completeOrder(widget.orderNumber, notes: _notesController.text, imagePath: _deliveryImage!.path);
    setState(() => _isProcessing = false);

    if (mounted) {
       if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('Pengantaran Selesai! Kerja Bagus! 🎉')));
          Navigator.pop(context, true);
       } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(result['message'] ?? 'Gagal')));
       }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 80);
    if (pickedFile != null) setState(() => _deliveryImage = File(pickedFile.path));
  }

  String _formatCurrency(num val) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val);

  @override
  // build method removed (duplicate)

  Widget _buildContent() {
    final detail = _orderDetail!;
    bool isReady = detail['status'] == 'READY';
    bool isOnDelivery = detail['status'] == 'ON_DELIVERY';
    bool isComplete = detail['status'] == 'COMPLETE';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBanner(detail['status']),
                const SizedBox(height: 16),
                
                // CUSTOMER & ADDRESS CARD
                Container(
                   padding: const EdgeInsets.all(20),
                   decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        const Text("SIAPA & DIMANA?", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        Text(detail['customer'] ?? '-', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                             const Icon(Icons.location_on, color: Colors.red),
                             const SizedBox(width: 8),
                             Expanded(child: Text(detail['alamat'] ?? '-', style: const TextStyle(fontSize: 16))),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                             Expanded(
                               child: ElevatedButton.icon(
                                  onPressed: () => _launchWhatsApp(detail['phone']),
                                  icon: const Icon(Icons.chat),
                                  label: const Text("WHATSAPP"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                               ),
                             ),
                             const SizedBox(width: 12),
                             if (detail['gmaps_url'] != null)
                               Expanded(
                                 child: ElevatedButton.icon(
                                    onPressed: () => _launchUrl(detail['gmaps_url']),
                                    icon: const Icon(Icons.map),
                                    label: const Text("NAVIGASI"),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                                 ),
                               ),
                          ],
                        ),

                        if (detail['notes'] != null && detail['notes'].toString().isNotEmpty && detail['notes'] != '-') ...[
                           const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                           const Text("CATATAN TAMBAHAN:", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
                           const SizedBox(height: 8),
                           Row(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                const Icon(Icons.note, size: 16, color: Colors.amber),
                                const SizedBox(width: 8),
                                Expanded(child: Text(detail['notes'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontStyle: FontStyle.italic))),
                             ],
                           )
                        ]
                     ],
                   ),
                ),

                const SizedBox(height: 16),
                
                // ITEMS
                Container(
                   padding: const EdgeInsets.all(20),
                   decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                   child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         const Text("ANTAR APA AJA?", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                         const Divider(),
                         ListView.builder(
                           shrinkWrap: true,
                           physics: const NeverScrollableScrollPhysics(),
                           itemCount: (detail['items'] as List).length,
                           itemBuilder: (context, index) {
                              final item = detail['items'][index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                   children: [
                                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)), child: Text("${item['quantity']}x", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900))),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(item['name'] ?? '-')),
                                   ],
                                ),
                              );
                           },
                         )
                      ],
                   ),
                ),

                if (isOnDelivery) ...[
                   const SizedBox(height: 24),
                   const Text("BUKTI PENGANTARAN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   const SizedBox(height: 12),
                   GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                         height: 200,
                         width: double.infinity,
                         decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                            image: _deliveryImage != null ? DecorationImage(image: FileImage(_deliveryImage!), fit: BoxFit.cover) : null
                         ),
                         child: _deliveryImage == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.camera_alt, size: 50, color: Colors.grey), SizedBox(height: 8), Text("FOTO BUKTI (WAJIB)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))]) : null,
                      ),
                   ),
                   const SizedBox(height: 12),
                   TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                         filled: true,
                         fillColor: Colors.white,
                         hintText: "Catatan (misal: diterima satpam)",
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                      ),
                   )
                ],
                const SizedBox(height: 100), // Space for bottom button
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatusBanner(String status) {
     Color bg = Colors.grey;
     String text = status;
     if (status == 'READY') { bg = Colors.blue; text = "SIAP DIAMBIL"; }
     else if (status == 'ON_DELIVERY') { bg = Colors.orange; text = "SEDANG DIANTAR"; }
     else if (status == 'COMPLETE') { bg = Colors.green; text = "SELESAI"; }
     
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
             Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
             if (status == 'COMPLETE') _buildCompletionDuration(_orderDetail!),
          ],
        ),
      );
  }

  Widget _buildCompletionDuration(Map<String, dynamic> detail) {
      // 1. Cari End Time: Priority completed_time -> completed_at -> updated_at -> delivery_proof.uploaded_at
      DateTime? completedAt = _parseDate(detail['completed_time']) ?? 
                              _parseDate(detail['completed_at']) ?? 
                              _parseDate(detail['updated_at']);
      
      if (completedAt == null && detail['delivery_proof'] != null) {
          completedAt = _parseDate(detail['delivery_proof']['uploaded_at']);
      }

      // 2. Cari Start Time
      // Priority: created_at (Total Duration)
      DateTime? startTime = _parseDate(detail['created_at']);
      String label = "Total Durasi";

      if (startTime == null) {
         if (detail['delivery_time'] != null) {
             startTime = _parseDate(detail['delivery_time']);
             label = "Durasi Pengantaran";
         } else if (detail['ready_time'] != null) {
             startTime = _parseDate(detail['ready_time']);
             label = "Durasi Sejak Siap";
         }
      }

      if (completedAt != null && startTime != null) {
          Duration diff = completedAt.difference(startTime);
          if (diff.isNegative) diff = Duration.zero;

          String durationText = "";
          if (diff.inHours > 0) durationText += "${diff.inHours} jam ";
          durationText += "${diff.inMinutes % 60} menit";
          if (durationText.trim().isEmpty) durationText = "< 1 menit";

          return Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
               "$label: $durationText",
               style: const TextStyle(color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          );
      }
      return const SizedBox.shrink();
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr == '-' || dateStr.isEmpty) return null;
    try {
      // 1. Try ISO
      final iso = DateTime.tryParse(dateStr);
      if (iso != null) return iso;
    } catch (_) {}

    try {
       // 2. Try SQL Format "2026-01-14 08:12:47"
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

  @override
  Widget build(BuildContext context) {
      // Re-structure to use bottom sheet for Main Action
      return Scaffold(
         backgroundColor: Colors.grey.shade100,
         appBar: AppBar(title: Text("Order #${widget.orderNumber}"), backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
         body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildContent(),
         bottomSheet: _orderDetail == null || _orderDetail!['status'] == 'COMPLETE' ? null : _buildBottomAction(),
      );
  }

  Widget _buildBottomAction() {
     bool isReady = _orderDetail!['status'] == 'READY';
     return Container(
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0,-5))]),
       child: SizedBox(
         width: double.infinity,
         height: 55,
         child: ElevatedButton(
            onPressed: isReady ? _handlePickup : _handleComplete,
            style: ElevatedButton.styleFrom(backgroundColor: isReady ? Colors.blue.shade700 : Colors.green.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _isProcessing 
               ? const CircularProgressIndicator(color: Colors.white)
               : Text(isReady ? "AMBIL ORDER SEKARANG" : "SELESAIKAN ORDER", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
         ),
       ),
     );
  }
}