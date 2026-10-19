import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class StockProcurementScreen extends StatefulWidget {
  const StockProcurementScreen({super.key});

  @override
  State<StockProcurementScreen> createState() => _StockProcurementScreenState();
}

class _StockProcurementScreenState extends State<StockProcurementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  List<dynamic> _procurements = [];
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _fetchProcurements();
      }
    });
    _currentUserRole = ApiService.getCachedRole()?.toLowerCase();
    _fetchProcurements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String? _getCurrentStatusFilter() {
    switch (_tabController.index) {
      case 1:
        return 'PENDING';
      case 2:
        return 'APPROVED';
      case 3:
        return 'RECEIVED';
      default:
        return null; // Semua
    }
  }

  Future<void> _fetchProcurements() async {
    setState(() => _isLoading = true);
    final status = _getCurrentStatusFilter();
    final res = await _apiService.getProcurements(status: status);

    if (mounted) {
      setState(() {
        if (res != null && res['success'] == true && res['data'] != null) {
          _procurements = List<dynamic>.from(res['data']['data'] ?? []);
        } else {
          _procurements = [];
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnerOrAdmin = _currentUserRole == 'owner' || _currentUserRole == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Pengadaan Stok Barang',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0284C7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Menunggu (Pending)'),
            Tab(text: 'Disetujui'),
            Tab(text: 'Selesai (Diterima)'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final refresh = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const StockProcurementCreateScreen()),
          );
          if (refresh == true) {
            _fetchProcurements();
          }
        },
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Buat Pengajuan', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProcurements,
        color: const Color(0xFF0284C7),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _procurements.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _procurements.length,
                    itemBuilder: (context, index) {
                      final item = _procurements[index];
                      return _buildProcurementCard(item, isOwnerOrAdmin);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined, size: 50, color: Color(0xFF0284C7)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Belum Ada Pengajuan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Klik tombol di bawah untuk membuat pengajuan pengadaan stok baru.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcurementCard(Map<String, dynamic> item, bool isOwnerOrAdmin) {
    final status = (item['status'] ?? 'PENDING').toString().toUpperCase();
    final items = (item['items'] as List<dynamic>?) ?? [];
    final requester = item['requester']?['name'] ?? 'Kasir';
    final number = item['procurement_number'] ?? '-';
    final createdAt = item['created_at'];

    final num totalAmount = (status == 'APPROVED' || status == 'RECEIVED')
        ? (item['total_approved_amount'] ?? 0)
        : (item['total_estimated_amount'] ?? 0);

    Color statusColor;
    Color statusBg;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'PENDING':
        statusColor = const Color(0xFFD97706); // Amber
        statusBg = const Color(0xFFFEF3C7);
        statusLabel = 'Menunggu Owner';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'APPROVED':
        statusColor = const Color(0xFF16A34A); // Green
        statusBg = const Color(0xFFDCFCE7);
        statusLabel = 'Disetujui Owner';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'RECEIVED':
        statusColor = const Color(0xFF0284C7); // Blue
        statusBg = const Color(0xFFE0F2FE);
        statusLabel = 'Selesai (Diterima)';
        statusIcon = Icons.done_all_rounded;
        break;
      case 'REJECTED':
      default:
        statusColor = const Color(0xFFDC2626); // Red
        statusBg = const Color(0xFFFEE2E2);
        statusLabel = 'Ditolak';
        statusIcon = Icons.cancel_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(createdAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body Card: Items Summary
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'Diajukan oleh: $requester',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Daftar Barang:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                ...items.map((it) {
                  final prodName = it['product']?['name'] ?? 'Produk';
                  final qtyReq = it['quantity_requested'] ?? 0;
                  final qtyApp = it['quantity_approved'] ?? qtyReq;
                  final isApp = it['is_approved'] != false;
                  final unitCogs = (status == 'APPROVED' || status == 'RECEIVED')
                      ? (it['unit_cogs_approved'] ?? it['unit_cogs_requested'] ?? 0)
                      : (it['unit_cogs_requested'] ?? 0);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isApp
                                ? '• $prodName (${(status == 'APPROVED' || status == 'RECEIVED') ? qtyApp : qtyReq} pcs @ ${_formatCurrency(unitCogs)})'
                                : '• $prodName (Dihapus Owner)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isApp ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                              decoration: isApp ? null : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        Text(
                          isApp
                              ? _formatCurrency(((status == 'APPROVED' || status == 'RECEIVED') ? qtyApp : qtyReq) * unitCogs)
                              : 'Rp 0',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isApp ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (status == 'APPROVED' || status == 'RECEIVED') ? 'Total Disetujui:' : 'Estimasi Total:',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    Text(
                      _formatCurrency(totalAmount),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: (status == 'APPROVED' || status == 'RECEIVED')
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
                if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sticky_note_2_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Catatan: ${item['notes']}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (item['owner_notes'] != null && item['owner_notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFD97706)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Catatan Owner: ${item['owner_notes']}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action Buttons
          if (status == 'PENDING' && isOwnerOrAdmin) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openOwnerReviewDialog(item),
                icon: const Icon(Icons.rate_review_rounded, size: 18),
                label: const Text('Review & Setujui Pengajuan', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else if (status == 'APPROVED') ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openReceiveDialog(item),
                icon: const Icon(Icons.inventory_rounded, size: 18),
                label: const Text('Barang Sudah Sampai (Terima Stok)', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- DIALOG REVIEW OWNER (BISA EDIT HARGA, EDIT QTY, HAPUS ITEM) ---
  void _openOwnerReviewDialog(Map<String, dynamic> procurement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OwnerReviewSheet(
        procurement: procurement,
        onSuccess: () {
          Navigator.pop(ctx);
          _fetchProcurements();
        },
      ),
    );
  }

  // --- DIALOG PENERIMAAN BARANG OLEH KASIR ---
  void _openReceiveDialog(Map<String, dynamic> procurement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReceiveGoodsSheet(
        procurement: procurement,
        onSuccess: () {
          Navigator.pop(ctx);
          _fetchProcurements();
        },
      ),
    );
  }
}

// =========================================================================
// 1. SCREEN FORM PENGAJUAN BARU OLEH KASIR
// =========================================================================
class StockProcurementCreateScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProduct;
  final List<Map<String, dynamic>>? initialProducts;
  const StockProcurementCreateScreen({
    super.key,
    this.initialProduct,
    this.initialProducts,
  });

  @override
  State<StockProcurementCreateScreen> createState() => _StockProcurementCreateScreenState();
}

class _StockProcurementCreateScreenState extends State<StockProcurementCreateScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<dynamic> _products = [];
  final List<Map<String, dynamic>> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getProducts();
    if (mounted) {
      if (res != null && res['success'] == true) {
        _products = List<dynamic>.from(res['data'] ?? []);
        if (widget.initialProduct != null) {
          _addItem(widget.initialProduct!);
        }
        if (widget.initialProducts != null) {
          for (var p in widget.initialProducts!) {
            _addItem(p);
          }
        }
      }
      setState(() => _isLoading = false);
    }
  }

  void _addItem(Map<String, dynamic> prod) {
    final dynamic idVal = prod['id'] ?? prod['product_id'];
    final int prodId = idVal is int ? idVal : (int.tryParse(idVal.toString()) ?? 0);
    if (prodId == 0) return;

    final existingIndex = _selectedItems.indexWhere((it) => it['product_id'] == prodId);
    if (existingIndex >= 0) {
      setState(() {
        _selectedItems[existingIndex]['quantity'] += 10;
        _selectedItems[existingIndex]['controller'].text = _selectedItems[existingIndex]['quantity'].toString();
      });
      return;
    }

    final int cogs = (prod['cogs'] ?? 0) is num ? (prod['cogs'] as num).toInt() : (int.tryParse(prod['cogs']?.toString() ?? '0') ?? 0);
    final int qty = (prod['suggested_qty'] ?? 10) is num ? (prod['suggested_qty'] as num).toInt() : (int.tryParse(prod['suggested_qty']?.toString() ?? '10') ?? 10);
    final controller = TextEditingController(text: qty.toString());

    setState(() {
      _selectedItems.add({
        'product_id': prodId,
        'name': prod['name'] ?? prod['nama'] ?? '-',
        'cogs': cogs,
        'stock': prod['stock'] ?? prod['stok_riil'] ?? prod['stok_sistem'] ?? 0,
        'quantity': qty,
        'controller': controller,
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems[index]['controller'].dispose();
      _selectedItems.removeAt(index);
    });
  }

  int _calculateTotalEstimated() {
    int total = 0;
    for (var it in _selectedItems) {
      final q = it['quantity'] as int;
      final c = it['cogs'] as int;
      total += (q * c);
    }
    return total;
  }

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  Future<void> _submitProcurement() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 barang untuk diajukan!'), backgroundColor: Colors.red),
      );
      return;
    }

    for (var it in _selectedItems) {
      if (it['quantity'] <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Jumlah ${it['name']} tidak boleh 0!'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final payloadItems = _selectedItems.map((it) => {
      'product_id': it['product_id'],
      'quantity': it['quantity'],
    }).toList();

    final res = await _apiService.createProcurement(
      items: payloadItems,
      notes: _notesController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Pengajuan berhasil dikirim!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal membuat pengajuan'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _calculateTotalEstimated();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Ajukan Belanja Stok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF0284C7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Kasir hanya memilih barang & jumlah yang dibutuhkan. Pengajuan akan diteruskan ke Owner untuk disetujui & dipotong dari Kas Besar.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF0369A1), height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header Barang & Tombol Tambah
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Barang yang Diajukan',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      TextButton.icon(
                        onPressed: _showProductPicker,
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text('Tambah Barang', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_selectedItems.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            'Belum ada barang yang dipilih',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _showProductPicker,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Pilih dari Daftar Produk'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._selectedItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final it = entry.value;
                      final cogs = it['cogs'] as int;
                      final qty = it['quantity'] as int;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    it['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Stok saat ini: ${it['stock']} • Modal: ${_formatCurrency(cogs)}',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Subtotal: ${_formatCurrency(qty * cogs)}',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Qty Stepper
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF64748B)),
                                  onPressed: () {
                                    if (qty > 1) {
                                      setState(() {
                                        it['quantity'] = qty - 1;
                                        it['controller'].text = (qty - 1).toString();
                                      });
                                    }
                                  },
                                ),
                                SizedBox(
                                  width: 45,
                                  child: TextField(
                                    controller: it['controller'],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    onChanged: (val) {
                                      final parsed = int.tryParse(val) ?? 0;
                                      setState(() => it['quantity'] = parsed);
                                    },
                                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0284C7)),
                                  onPressed: () {
                                    setState(() {
                                      it['quantity'] = qty + 1;
                                      it['controller'].text = (qty + 1).toString();
                                    });
                                  },
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              onPressed: () => _removeItem(idx),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 20),

                  // Catatan Kasir
                  const Text('Catatan Pengajuan (Opsional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Misal: Galon banyak yang pecah / supplier datang besok',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Total & Submit
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Estimasi Total Pengeluaran:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            Text(
                              _formatCurrency(total),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitProcurement,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('KIRIM PENGAJUAN KE OWNER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showProductPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Pilih Produk untuk Pengadaan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _products.length,
                itemBuilder: (ctx, i) {
                  final p = _products[i];
                  final stock = p['stock'] ?? 0;
                  final cogs = (p['cogs'] ?? 0) as int;

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0284C7), size: 20),
                    ),
                    title: Text(p['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Sisa Stok: $stock • Modal: ${_formatCurrency(cogs)}', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.add_circle, color: Color(0xFF0284C7)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _addItem(p);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 2. MODAL REVIEW & APPROVE OWNER (BISA EDIT QTY, EDIT HARGA, HAPUS ITEM)
// =========================================================================
class _OwnerReviewSheet extends StatefulWidget {
  final Map<String, dynamic> procurement;
  final VoidCallback onSuccess;

  const _OwnerReviewSheet({required this.procurement, required this.onSuccess});

  @override
  State<_OwnerReviewSheet> createState() => _OwnerReviewSheetState();
}

class _OwnerReviewSheetState extends State<_OwnerReviewSheet> {
  final ApiService _apiService = ApiService();
  final TextEditingController _ownerNotesController = TextEditingController();

  late List<Map<String, dynamic>> _editableItems;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final rawItems = (widget.procurement['items'] as List<dynamic>?) ?? [];
    _editableItems = rawItems.map((it) {
      final qty = (it['quantity_requested'] ?? 0) as int;
      final cogs = (it['unit_cogs_requested'] ?? 0) as int;
      return {
        'item_id': it['id'],
        'name': it['product']?['name'] ?? 'Produk',
        'current_stock': it['current_stock'] ?? 0,
        'quantity': qty,
        'unit_cogs': cogs,
        'is_approved': true,
        'qtyController': TextEditingController(text: qty.toString()),
        'cogsController': TextEditingController(text: cogs.toString()),
      };
    }).toList();
  }

  @override
  void dispose() {
    _ownerNotesController.dispose();
    for (var it in _editableItems) {
      it['qtyController'].dispose();
      it['cogsController'].dispose();
    }
    super.dispose();
  }

  int _calculateApprovedTotal() {
    int total = 0;
    for (var it in _editableItems) {
      if (it['is_approved'] == true) {
        total += ((it['quantity'] as int) * (it['unit_cogs'] as int));
      }
    }
    return total;
  }

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  Future<void> _submitReview(String action) async {
    final int id = widget.procurement['id'];

    if (action == 'APPROVE' && _calculateApprovedTotal() <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada barang yang disetujui untuk dibeli!'), backgroundColor: Colors.red),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(action == 'APPROVE' ? 'Setujui Pengadaan?' : 'Tolak Pengajuan?'),
        content: Text(
          action == 'APPROVE'
              ? 'Saldo KAS BESAR akan langsung dipotong sebesar ${_formatCurrency(_calculateApprovedTotal())}. Pastikan data sudah benar.'
              : 'Pengajuan ini akan ditolak dan tidak ada kas yang dikeluarkan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'APPROVE' ? const Color(0xFF16A34A) : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(action == 'APPROVE' ? 'Ya, Setujui & Potong Kas' : 'Ya, Tolak'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    final payloadItems = _editableItems.map((it) => {
      'item_id': it['item_id'],
      'quantity': it['quantity'],
      'unit_cogs': it['unit_cogs'],
      'is_approved': it['is_approved'],
    }).toList();

    final res = await _apiService.reviewProcurement(
      id: id,
      action: action,
      ownerNotes: _ownerNotesController.text.trim(),
      items: action == 'APPROVE' ? payloadItems : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Berhasil diproses!'), backgroundColor: Colors.green),
        );
        widget.onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal memproses'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalApproved = _calculateApprovedTotal();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Review Pengadaan Owner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                    Text('No: ${widget.procurement['procurement_number']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Owner dapat mengubah Quantity, mengedit Harga Beli asli (update modal di database), atau menghapus barang yang belum perlu dibeli.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Daftar Barang yang Diajukan Kasir:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),

                ..._editableItems.map((it) {
                  final bool isApp = it['is_approved'] == true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isApp ? Colors.white : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isApp ? const Color(0xFFCBD5E1) : Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                it['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isApp ? const Color(0xFF0F172A) : Colors.grey,
                                  decoration: isApp ? null : TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  isApp ? 'Beli' : 'Dihapus',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isApp ? Colors.green : Colors.red),
                                ),
                                Switch(
                                  value: isApp,
                                  activeColor: const Color(0xFF16A34A),
                                  onChanged: (val) {
                                    setState(() => it['is_approved'] = val);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (isApp) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Edit Qty
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Jumlah (Qty):', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: it['qtyController'],
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onChanged: (v) {
                                        setState(() => it['quantity'] = int.tryParse(v) ?? 0);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Edit Unit Cogs
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Harga Beli / Modal (Rp):', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: it['cogsController'],
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onChanged: (v) {
                                        setState(() => it['unit_cogs'] = int.tryParse(v) ?? 0);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Subtotal: ${_formatCurrency((it['quantity'] as int) * (it['unit_cogs'] as int))}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0284C7)),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 10),
                const Text('Catatan Owner (Opsional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _ownerNotesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Misal: Disetujui 30 galon dulu karena kas besar terbatas',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bar Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Kas Besar Dipotong:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      _formatCurrency(totalApproved),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => _submitReview('REJECT'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : () => _submitReview('APPROVE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('SETUJUI & POTONG KAS', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 3. MODAL TERIMA BARANG OLEH KASIR (UPLOAD NOTA SUPPLIER & UPDATE STOK)
// =========================================================================
class _ReceiveGoodsSheet extends StatefulWidget {
  final Map<String, dynamic> procurement;
  final VoidCallback onSuccess;

  const _ReceiveGoodsSheet({required this.procurement, required this.onSuccess});

  @override
  State<_ReceiveGoodsSheet> createState() => _ReceiveGoodsSheetState();
}

class _ReceiveGoodsSheetState extends State<_ReceiveGoodsSheet> {
  final ApiService _apiService = ApiService();
  File? _proofImage;
  bool _isSubmitting = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => _proofImage = File(picked.path));
    }
  }

  Future<void> _submitReceive() async {
    setState(() => _isSubmitting = true);

    final res = await _apiService.receiveProcurement(
      id: widget.procurement['id'],
      proofImage: _proofImage,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Barang berhasil diterima!'), backgroundColor: Colors.green),
        );
        widget.onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal menerima barang'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (widget.procurement['items'] as List<dynamic>?) ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Konfirmasi Barang Diterima', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('No Pengadaan: ${widget.procurement['procurement_number']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 14),

            const Text('Barang yang Disetujui & Masuk ke Stok:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            const SizedBox(height: 6),
            ...items.where((it) => it['is_approved'] != false).map((it) {
              return Text(
                '• ${it['product']?['name']} : +${it['quantity_approved']} pcs',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
              );
            }),
            const SizedBox(height: 16),

            // Foto Bukti / Nota Supplier
            const Text('Foto Nota / Surat Jalan Supplier (Wajib / Dianjurkan):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Ambil Foto Kamera'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickImage(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Pilih dari Galeri'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickImage(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: _proofImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_proofImage!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, color: Color(0xFF0284C7), size: 30),
                          SizedBox(height: 4),
                          Text('Klik untuk foto nota fisik supplier', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitReceive,
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('SIMPAN & TAMBAH KE STOK', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
