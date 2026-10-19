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
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _allProducts = [];
  String _searchQuery = '';
  String _selectedCategory = 'SEMUA';
  List<Map<String, dynamic>> _categoryOptions = [
    {'value': 'SEMUA', 'label': 'Semua'},
  ];

  // Cart state: Map<productId, quantity> & Map<productId, productData>
  final Map<int, int> _cartQuantities = {};
  final Map<int, Map<String, dynamic>> _cartProducts = {};

  @override
  void initState() {
    super.initState();
    _fetchCatalog();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int _safeInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  Future<void> _fetchCatalog() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getProcurementCatalog();
    if (mounted) {
      if (res != null && res['success'] == true) {
        final recs = (res['recommendations'] as List<dynamic>?) ?? [];
        final prods = (res['all_products'] as List<dynamic>?) ?? [];
        final types = (res['product_types'] as List<dynamic>?) ?? [];

        _recommendations = recs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _allProducts = prods.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        if (types.isNotEmpty) {
          _categoryOptions = types.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          if (!_categoryOptions.any((c) => c['value'] == 'SEMUA')) {
            _categoryOptions.insert(0, {'value': 'SEMUA', 'label': 'Semua'});
          }
        } else {
          // Dynamic fallback dari data produk yang ada
          final distinctTypes = _allProducts
              .map((p) => p['product_type']?.toString().toUpperCase())
              .where((t) => t != null && t.isNotEmpty)
              .toSet();
          _categoryOptions = [{'value': 'SEMUA', 'label': 'Semua'}];
          for (var dt in distinctTypes) {
            String label = dt!;
            if (dt == 'REFILL') label = 'Isi Ulang';
            if (dt == 'NEW_UNIT') label = 'Unit Baru';
            if (dt == 'CONSUMABLE') label = 'Barang Konsumsi';
            _categoryOptions.add({'value': dt, 'label': label});
          }
        }

        // Pre-fill dari Opname jika ada
        if (widget.initialProduct != null) {
          _addToCart(widget.initialProduct!);
        }
        if (widget.initialProducts != null) {
          for (var p in widget.initialProducts!) {
            _addToCart(p);
          }
        }
      }
      setState(() => _isLoading = false);
    }
  }

  void _addToCart(Map<String, dynamic> prod, {int? quantity}) {
    final int pid = _safeInt(prod['id'] ?? prod['product_id']);
    if (pid == 0) return;

    final int defaultQty = quantity ?? _safeInt(prod['suggested_quantity'] ?? prod['suggested_qty'] ?? 10);
    final int finalQty = defaultQty > 0 ? defaultQty : 1;

    setState(() {
      _cartProducts[pid] = prod;
      // Selalu gunakan nilai terbaru yang dipilih/diinput (replace/update, bukan diakumulasikan)
      _cartQuantities[pid] = finalQty;
    });
  }

  Future<void> _showEditQtyDialog(int pid, String productName, int currentQty, [void Function()? onUpdated]) async {
    final controller = TextEditingController(text: currentQty.toString());
    final newQty = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Ubah Jumlah Pesan\n$productName',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Jumlah',
            hintText: 'Misal: 2',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim()) ?? 0;
              Navigator.pop(ctx, val);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newQty != null) {
      _updateCartQty(pid, newQty);
      if (onUpdated != null) onUpdated();
    }
  }

  void _updateCartQty(int pid, int qty) {
    setState(() {
      if (qty <= 0) {
        _cartQuantities.remove(pid);
        _cartProducts.remove(pid);
      } else {
        _cartQuantities[pid] = qty;
      }
    });
  }

  void _removeFromCart(int pid) {
    setState(() {
      _cartQuantities.remove(pid);
      _cartProducts.remove(pid);
    });
  }

  void _addAllRecommendations([List<Map<String, dynamic>>? targetList]) {
    final list = targetList ?? _recommendations;
    if (list.isEmpty) return;
    int addedCount = 0;
    setState(() {
      for (var r in list) {
        final pid = _safeInt(r['id'] ?? r['product_id']);
        if (pid == 0) continue;
        _cartProducts[pid] = r;
        final int sugg = _safeInt(r['suggested_quantity'] ?? 10);
        _cartQuantities[pid] = sugg > 0 ? sugg : 10;
        addedCount++;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ $addedCount produk rekomendasi ditambahkan ke keranjang!'),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  int _calculateTotal() {
    int total = 0;
    _cartQuantities.forEach((pid, qty) {
      final prod = _cartProducts[pid];
      final cogs = _safeInt(prod?['cogs']);
      total += (qty * cogs);
    });
    return total;
  }

  Future<void> _submitProcurement() async {
    if (_cartQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang masih kosong! Pilih minimal 1 barang.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payloadItems = _cartQuantities.entries.map((e) => {
      'product_id': e.key,
      'quantity': e.value,
    }).toList();

    final res = await _apiService.createProcurement(
      items: payloadItems,
      notes: _notesController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Pengajuan pengadaan berhasil dikirim ke Owner!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Gagal membuat pengajuan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final total = _calculateTotal();
          final items = _cartQuantities.entries.toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_cart_rounded, color: Color(0xFF0284C7), size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Keranjang Belanja (${items.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      if (items.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _cartQuantities.clear();
                              _cartProducts.clear();
                            });
                            setSheetState(() {});
                            Navigator.pop(ctx);
                          },
                          child: const Text('Kosongkan', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Cart items list
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 50, color: Colors.grey),
                              SizedBox(height: 10),
                              Text('Keranjang masih kosong', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final entry = items[index];
                            final pid = entry.key;
                            final qty = entry.value;
                            final prod = _cartProducts[pid] ?? {};
                            final name = prod['name'] ?? prod['nama'] ?? 'Produk #$pid';
                            final cogs = _safeInt(prod['cogs']);
                            final unit = prod['unit'] ?? 'pcs';
                            final subtotal = qty * cogs;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Modal: ${_formatCurrency(cogs)} / $unit',
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Subtotal: ${_formatCurrency(subtotal)}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Stepper
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove, size: 16),
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            _updateCartQty(pid, qty - 1);
                                            setSheetState(() {});
                                          },
                                        ),
                                        InkWell(
                                          onTap: () => _showEditQtyDialog(pid, name, qty, () => setSheetState(() {})),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Text(
                                              '$qty',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 16),
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            _updateCartQty(pid, qty + 1);
                                            setSheetState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                    onPressed: () {
                                      _removeFromCart(pid);
                                      setSheetState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Notes & Checkout Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3)),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        TextField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Catatan pengadaan untuk Owner (opsional)...',
                            hintStyle: const TextStyle(fontSize: 12),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Est. Kas Besar:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569))),
                            Text(
                              _formatCurrency(total),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0284C7)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (_isSubmitting || items.isEmpty)
                                ? null
                                : () async {
                                    Navigator.pop(ctx);
                                    await _submitProcurement();
                                  },
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: _isSubmitting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('AJUKAN PENGADAAN KE OWNER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecommendations = _recommendations.where((rec) {
      if (_searchQuery.isNotEmpty) {
        final name = (rec['name'] ?? '').toString().toLowerCase();
        final sku = (rec['sku'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!name.contains(q) && !sku.contains(q)) return false;
      }
      if (_selectedCategory != 'SEMUA') {
        final pType = (rec['product_type'] ?? '').toString().toUpperCase();
        if (pType != _selectedCategory.toUpperCase()) return false;
      }
      return true;
    }).toList();

    final filteredCatalog = _allProducts.where((p) {
      if (_searchQuery.isNotEmpty) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final sku = (p['sku'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!name.contains(q) && !sku.contains(q)) return false;
      }
      if (_selectedCategory != 'SEMUA') {
        final pType = (p['product_type'] ?? '').toString().toUpperCase();
        if (pType != _selectedCategory.toUpperCase()) return false;
      }
      return true;
    }).toList();

    final totalCartPrice = _calculateTotal();
    final totalCartCount = _cartQuantities.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'Pengadaan Barang (Restock)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
            ),
            Text(
              'Smart Cart & Rekomendasi Ambang Batas',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.normal),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0284C7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_rounded, color: Colors.white),
                if (totalCartCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        '$totalCartCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _openCartBottomSheet,
            tooltip: 'Buka Keranjang',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ========================================================
                // STICKY TOP: 🔍 SEARCH BAR & 🏷️ FILTER KATEGORI DI ATAS
                // ========================================================
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Cari nama barang, galon, tisu, filter...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7), size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Horizontal Scrollable Category Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categoryOptions.map((opt) {
                            final isSelected = _selectedCategory == opt['value'];
                            final label = opt['label'] ?? opt['value'] ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(label),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedCategory = opt['value']);
                                  }
                                },
                                selectedColor: const Color(0xFFE0F2FE),
                                backgroundColor: const Color(0xFFF8FAFC),
                                labelStyle: TextStyle(
                                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF475569),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // ========================================================
                // LIST KONTEN UTAMA DENGAN REKOMENDASI & KATALOG
                // ========================================================
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchCatalog,
                    child: Stack(
                      children: [
                        ListView(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, totalCartCount > 0 ? 100 : 30),
                          children: [
                            // ========================================================
                            // SECTION 1: ⚡ REKOMENDASI RESTOCK HARI INI
                            // ========================================================
                            Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 22),
                                    SizedBox(width: 6),
                                    Text(
                                      'Rekomendasi Restock Hari Ini ⚡',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                                    ),
                                  ],
                                ),
                                if (filteredRecommendations.isNotEmpty)
                                  InkWell(
                                    onTap: () => _addAllRecommendations(filteredRecommendations),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '+ Ambil Semua',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Otomatis disaring dari barang laku hari ini & stok menyentuh ambang batas (low_stock_threshold).',
                              style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                            ),
                            const SizedBox(height: 12),

                            if (filteredRecommendations.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _recommendations.isEmpty ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                      color: _recommendations.isEmpty ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _recommendations.isEmpty
                                            ? 'Semua stok barang saat ini masih di atas ambang batas aman 👍'
                                            : 'Tidak ada rekomendasi restock untuk kategori / pencarian ini.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _recommendations.isEmpty ? const Color(0xFF166534) : const Color(0xFF92400E),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...filteredRecommendations.map((rec) {
                                final pid = _safeInt(rec['id'] ?? rec['product_id']);
                                final name = rec['name'] ?? '-';
                                final currentStock = _safeInt(rec['current_stock']);
                                final threshold = _safeInt(rec['low_stock_threshold'] ?? 10);
                                final soldToday = _safeInt(rec['sold_today']);
                                final cogs = _safeInt(rec['cogs']);
                                final unit = rec['unit'] ?? 'pcs';
                                final suggestedQty = _safeInt(rec['suggested_quantity'] ?? 10);
                                final isLow = rec['is_low_stock'] == true;
                                final inCartQty = _cartQuantities[pid] ?? 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: inCartQty > 0 ? const Color(0xFF0284C7) : const Color(0xFFFDE68A),
                                      width: inCartQty > 0 ? 1.5 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                            ),
                                          ),
                                          if (isLow)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEE2E2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Kritis (≤ Min $threshold)',
                                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          _buildBadge('Sisa: $currentStock $unit', isLow ? const Color(0xFFDC2626) : const Color(0xFF475569), isLow ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9)),
                                          _buildBadge('Terjual: $soldToday', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                                          _buildBadge('Min: $threshold', const Color(0xFF7C3AED), const Color(0xFFF3E8FF)),
                                          _buildBadge('Modal: ${_formatCurrency(cogs)}', const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Saran Restock: +$suggestedQty $unit',
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                          ),
                                          if (inCartQty > 0)
                                            Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE0F2FE),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFF0284C7)),
                                              ),
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.remove, size: 16, color: Color(0xFF0284C7)),
                                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () => _updateCartQty(pid, inCartQty - 1),
                                                  ),
                                                  InkWell(
                                                    onTap: () => _showEditQtyDialog(pid, name, inCartQty),
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      child: Text(
                                                        '$inCartQty',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.add, size: 16, color: Color(0xFF0284C7)),
                                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () => _updateCartQty(pid, inCartQty + 1),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            ElevatedButton.icon(
                                              onPressed: () => _addToCart(rec, quantity: suggestedQty),
                                              icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                                              label: Text('+ Keranjang ($suggestedQty)'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF0284C7),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ========================================================
                      // SECTION 2: 📦 KATALOG SELURUH BARANG
                      // ========================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Katalog Seluruh Barang 📦',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${filteredCatalog.length} produk',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // List all products
                      if (filteredCatalog.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: const Center(
                            child: Text('Barang tidak ditemukan untuk filter ini', style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      else
                        ...filteredCatalog.map((prod) {
                          final pid = _safeInt(prod['id'] ?? prod['product_id']);
                          final name = prod['name'] ?? '-';
                          final stock = _safeInt(prod['current_stock']);
                          final threshold = _safeInt(prod['low_stock_threshold'] ?? 10);
                          final cogs = _safeInt(prod['cogs']);
                          final unit = prod['unit'] ?? 'pcs';
                          final inCartQty = _cartQuantities[pid] ?? 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: inCartQty > 0 ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                width: inCartQty > 0 ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: inCartQty > 0 ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    color: inCartQty > 0 ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Stok: $stock $unit (Min: $threshold) • Modal: ${_formatCurrency(cogs)}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (inCartQty > 0)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF0284C7)),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove, size: 14, color: Color(0xFF0284C7)),
                                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                          padding: EdgeInsets.zero,
                                          onPressed: () => _updateCartQty(pid, inCartQty - 1),
                                        ),
                                        InkWell(
                                          onTap: () => _showEditQtyDialog(pid, name, inCartQty),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            child: Text(
                                              '$inCartQty',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0284C7)),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 14, color: Color(0xFF0284C7)),
                                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                          padding: EdgeInsets.zero,
                                          onPressed: () => _updateCartQty(pid, inCartQty + 1),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  OutlinedButton.icon(
                                    onPressed: () => _addToCart(prod, quantity: 10),
                                    icon: const Icon(Icons.add, size: 14),
                                    label: const Text('+ Keranjang'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0284C7),
                                      side: const BorderSide(color: Color(0xFF0284C7)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),

                  // ========================================================
                  // SECTION 3: 🛒 FLOATING CART BAR (MELAYANG DI BAWAH)
                  // ========================================================
                  if (totalCartCount > 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              // Cart Icon with badge
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(Icons.shopping_cart_rounded, color: Color(0xFF0284C7), size: 24),
                                    Positioned(
                                      right: -6,
                                      top: -6,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        child: Text(
                                          '$totalCartCount',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Info total
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$totalCartCount Barang Dipilih',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                    ),
                                    Text(
                                      _formatCurrency(totalCartPrice),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0284C7)),
                                    ),
                                  ],
                                ),
                              ),
                              // Button Lihat Keranjang
                              ElevatedButton(
                                onPressed: _openCartBottomSheet,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Row(
                                  children: [
                                    Text('LIHAT KERANJANG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 12),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor)),
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
