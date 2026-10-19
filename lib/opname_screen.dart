import 'package:flutter/material.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';
import 'stock_procurement_screen.dart';

class OpnameScreen extends StatefulWidget {
  const OpnameScreen({super.key});

  @override
  State<OpnameScreen> createState() => _OpnameScreenState();
}

class _OpnameScreenState extends State<OpnameScreen> {
  final ApiService _apiService = ApiService();
  
  List<dynamic> _masterList = [];
  List<dynamic> _filteredList = [];
  
  bool _isLoading = true;
  
  // Controller & Map untuk menyimpan status interaktif
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, String> _diffStatus = {}; 
  final Map<int, int> _diffValue = {}; 
  
  // Track pengajuan belanja selama sesi opname ini: productId -> {qty, status}
  final Map<int, Map<String, dynamic>> _procurementRequests = {};
  
  final TextEditingController _notesController = TextEditingController(text: 'Opname Harian');
  final TextEditingController _searchController = TextEditingController(); 

  // --- STATE DATA ---
  String _opnameInfo = 'Memuat...';
  Map<String, dynamic> _ringkasan = {};
  List<dynamic> _soldProductsToday = [];
  
  // --- Filter State ---
  String _currentFilter = 'TERJUAL'; // Default ke TERJUAL HARI INI
  final List<String> _filterOptions = ['SEMUA', 'TERJUAL', 'DAILY', 'NORMAL', 'KURANG', 'LEBIH']; 

  @override
  void initState() {
    super.initState();
    _fetchOpnameList();
  }

  @override
  void dispose() {
    _qtyControllers.forEach((key, controller) => controller.dispose());
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int safeInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      if (val is num) return val.toInt();
      return 0;
  }

  void _calculateDifference(int productId, int systemQty, String? realQtyString) {
      final realQty = int.tryParse(realQtyString ?? '0') ?? 0;
      final difference = systemQty - realQty; 
      
      String status;
      if (difference == 0) {
          status = 'normal';
      } else if (difference > 0) {
          status = 'kurang';
      } else {
          status = 'lebih';
      }

      _diffStatus[productId] = status;
      _diffValue[productId] = difference;
      
      // Update UI jika filter sedang aktif
      if (_currentFilter != 'SEMUA' && _currentFilter != 'TERJUAL' && status.toUpperCase() != _currentFilter) {
          // Jika item statusnya berubah dan tidak sesuai filter status (KURANG/LEBIH/NORMAL), refresh list
           _runFilter(null);
      } else {
          // Refresh UI lokal (warna border berubah)
          setState(() {}); 
      }
  }

  void _runFilter(String? keyword) {
    final searchKeyword = keyword?.toLowerCase() ?? _searchController.text.toLowerCase();
    List<dynamic> results = _masterList;

    // 1. Filter berdasarkan STATUS / TERJUAL / DAILY
    if (_currentFilter == 'TERJUAL') {
        results = results.where((item) => safeInt(item['terjual_hari_ini']) > 0).toList();
    } else if (_currentFilter == 'DAILY') {
        // List produk rutin harian (Hardcoded sesuai request)
        final dailyKeywords = [
           'gas 3kg antar', 
           'le mineral 15l', 
           'aqua 19l',
        ];

        results = results.where((item) {
             final name = item['nama'].toString().toLowerCase();
             // Cek apakah nama produk mengandung salah satu keyword
             return dailyKeywords.any((keyword) => name.contains(keyword));
        }).toList();
    } else if (_currentFilter != 'SEMUA') {
        final targetStatus = _currentFilter.toLowerCase();
        results = results.where((item) => (_diffStatus[safeInt(item['product_id'])] ?? 'normal') == targetStatus).toList();
    }
    
    // 2. Filter berdasarkan KEYWORD
    if (searchKeyword.isNotEmpty) {
      results = results
          .where((item) =>
              item['nama'].toString().toLowerCase().contains(searchKeyword)) 
          .toList();
    }

    setState(() {
      _filteredList = results;
    });
  }

  Future<void> _fetchOpnameList() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getOpnameList();
      
      if (mounted) {
        final list = result?['data'] ?? [];
        final ringkasanData = result?['ringkasan'] ?? {};
        final opnameInfo = result?['opname_info'] ?? 'Opname Stok';
        final soldProducts = result?['produk_terjual_hari_ini'] ?? [];

        setState(() {
          _masterList = list;
          // _filteredList = list; // HAPUS INI, karena kita mau filter jalan
          _ringkasan = ringkasanData;
          _opnameInfo = opnameInfo;
          _soldProductsToday = soldProducts;
          
          _qtyControllers.clear();
          _diffStatus.clear();
          _diffValue.clear();

          for (var item in list) {
            final productId = safeInt(item['product_id']);
            final realQtyDB = safeInt(item['stok_riil']);
            final systemQty = safeInt(item['stok_sistem']); 
            
            if (productId != 0) {
              _qtyControllers[productId] = TextEditingController(text: realQtyDB.toString());
              _calculateDifference(productId, systemQty, realQtyDB.toString());
            }
          }
          _isLoading = false; 

          // APPLY DEFAULT FILTER (TERJUAL) LANGSUNG SETELAH DATA LOAD
          WidgetsBinding.instance.addPostFrameCallback((_) {
              _runFilter(null);
          });
        });
      }
    } catch (e) {
      print("Error fetching opname: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitOpname() async {
    FocusScope.of(context).unfocus();
    if (_masterList.isEmpty) return;

    List<Map<String, dynamic>> submitData = [];
    for (var item in _masterList) {
      final productId = safeInt(item['product_id']);
      if (productId == 0) continue;

      final controller = _qtyControllers[productId];
      final inputQty = int.tryParse(controller?.text.trim() ?? '0') ?? 0;
      
      submitData.add({
        'product_id': productId,
        'real_quantity': inputQty,
      });
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simpan Opname?'),
        content: const Text('Pastikan semua data input sudah benar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true), 
            child: const Text('Simpan')
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() => _isLoading = true);
    final success = await _apiService.postOpname(submitData, _notesController.text.trim());

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Data Opname Tersimpan!'), backgroundColor: Colors.green),
        );
        _searchController.clear(); 
        await _fetchOpnameList(); 
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Gagal menyimpan data.'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Color _getDiffColor(String status) {
      switch (status) {
          case 'kurang': return Colors.red;
          case 'lebih': return Colors.green;
          default: return Colors.grey;
      }
  }

  void _showSoldProductsDetail(BuildContext context) {
    if (_soldProductsToday.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Produk Terjual Hari Ini'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _soldProductsToday.length,
            itemBuilder: (context, index) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: Text('${index + 1}', style: const TextStyle(color: Colors.blue)),
              ),
              title: Text(_soldProductsToday[index]),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
      ),
    );
  }

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  int get _lowStockCount {
    return _masterList.where((it) {
      final pid = safeInt(it['product_id']);
      final rq = int.tryParse(_qtyControllers[pid]?.text.trim() ?? '') ?? safeInt(it['stok_riil']);
      return rq <= 5 && !_procurementRequests.containsKey(pid);
    }).length;
  }

  void _openQuickProcurementSheet(BuildContext context, Map<String, dynamic> item, int currentRealQty) {
    final productId = safeInt(item['product_id']);
    final productName = item['nama'] ?? '-';
    final unit = item['unit'] ?? 'pcs';
    final int cogs = safeInt(item['cogs']);

    int buyQty = 50;
    final buyQtyController = TextEditingController(text: buyQty.toString());
    final notesController = TextEditingController(text: 'Stok sisa $currentRealQty $unit saat opname malam');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final int inputQty = int.tryParse(buyQtyController.text.trim()) ?? 0;
          final int totalCost = inputQty * cogs;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF0284C7), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Sisa Fisik: $currentRealQty $unit • Modal: ${_formatCurrency(cogs)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Jumlah Pengajuan Beli:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                      Text('Satuan: $unit', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          int cur = int.tryParse(buyQtyController.text.trim()) ?? 0;
                          if (cur > 10) cur -= 10;
                          else if (cur > 1) cur -= 1;
                          setModalState(() {
                            buyQtyController.text = cur.toString();
                          });
                        },
                        icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF0284C7), size: 28),
                      ),
                      Expanded(
                        child: TextField(
                          controller: buyQtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF0284C7)),
                          onChanged: (_) => setModalState(() {}),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            suffixText: unit,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          int cur = int.tryParse(buyQtyController.text.trim()) ?? 0;
                          cur += 10;
                          setModalState(() {
                            buyQtyController.text = cur.toString();
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0284C7), size: 28),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [10, 25, 50, 100].map((preset) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              setModalState(() {
                                buyQtyController.text = preset.toString();
                              });
                            },
                            child: Text('+$preset', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estimasi Beban Kas Besar:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$inputQty $unit × ${_formatCurrency(cogs)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                            ),
                          ],
                        ),
                        Text(
                          _formatCurrency(totalCost),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Catatan untuk Owner (Opsional)',
                      labelStyle: const TextStyle(fontSize: 12),
                      hintText: 'Misal: Stok menipis, butuh restock besok pagi',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.shield_outlined, size: 16, color: Color(0xFF1D4ED8)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kasir dilarang beli stok pakai kas laci fisik. Pembelian stok dipotong langsung dari Kas Besar setelah disetujui Owner.',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF1E40AF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: () {
                      final submitQty = int.tryParse(buyQtyController.text.trim()) ?? 0;
                      if (submitQty <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Jumlah beli harus lebih dari 0'), backgroundColor: Colors.orange),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      _submitSingleProcurement(
                        productId: productId,
                        productName: productName,
                        qty: submitQty,
                        unit: unit,
                        notes: notesController.text.trim(),
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('KIRIM PENGAJUAN KE OWNER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitSingleProcurement({
    required int productId,
    required String productName,
    required int qty,
    required String unit,
    required String notes,
  }) async {
    setState(() => _isLoading = true);
    final res = await _apiService.createProcurement(
      items: [
        {
          'product_id': productId,
          'quantity': qty,
        }
      ],
      notes: notes.isNotEmpty ? notes : 'Pengajuan dari Stok Opname',
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res['success'] == true) {
        setState(() {
          _procurementRequests[productId] = {
            'qty': qty,
            'status': 'PENDING',
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Pengajuan $qty $unit $productName berhasil dikirim ke Owner!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal mengajukan: ${res['message'] ?? 'Terjadi kesalahan'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openBatchProcurement() async {
    final lowStockItems = _masterList.where((it) {
      final pid = safeInt(it['product_id']);
      final rq = int.tryParse(_qtyControllers[pid]?.text.trim() ?? '') ?? safeInt(it['stok_riil']);
      return rq <= 5 && !_procurementRequests.containsKey(pid);
    }).map((it) {
      final pid = safeInt(it['product_id']);
      final rq = int.tryParse(_qtyControllers[pid]?.text.trim() ?? '') ?? safeInt(it['stok_riil']);
      return {
        'product_id': pid,
        'name': it['nama'],
        'cogs': safeInt(it['cogs']),
        'stock': rq,
        'suggested_qty': 50,
      };
    }).toList();

    if (lowStockItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua barang kritis sudah diajukan atau stok masih aman.'), backgroundColor: Colors.blue),
      );
      return;
    }

    final refresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StockProcurementCreateScreen(
          initialProducts: lowStockItems,
        ),
      ),
    );

    if (refresh == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Pengajuan belanja berhasil dikirim ke Owner!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Opname Stok', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_opnameInfo, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
            IconButton(
                onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StockProcurementScreen()),
                    );
                },
                icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7)),
                tooltip: 'Pengadaan Stok',
            ),
            TextButton.icon(
                onPressed: _isLoading ? null : _submitOpname,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('SIMPAN'),
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchOpnameList,
              child: Column(
                children: [
                  // --- HEADER SECTION ---
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.black12))
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // INFO BOXES
                        Row(
                          children: [
                            _buildStatCard('Kurang', _ringkasan['produk_kurang'] ?? 0, Colors.red),
                            const SizedBox(width: 12),
                            _buildStatCard('Lebih', _ringkasan['produk_lebih'] ?? 0, Colors.green),
                            const SizedBox(width: 12),
                            _buildStatCard('Terjual', _ringkasan['total_terjual_hari_ini'] ?? 0, Colors.blue),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // SEARCH & FILTER
                        Row(
                            children: [
                                Expanded(
                                    child: TextField(
                                        controller: _searchController,
                                        onChanged: (val) => _runFilter(val),
                                        decoration: InputDecoration(
                                            hintText: 'Cari barang...',
                                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                            filled: true,
                                            fillColor: Colors.grey.shade100,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        ),
                                    ),
                                ),
                            ],
                        ),
                        
                        // CHIPS FILTER
                        SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                                children: _filterOptions.map((filter) {
                                    final isSelected = _currentFilter == filter;
                                    Color color;
                                    if (filter == 'KURANG') color = Colors.red;
                                    else if (filter == 'LEBIH') color = Colors.green;
                                    else if (filter == 'TERJUAL') color = Colors.orange;
                                    else if (filter == 'DAILY') color = Colors.purple;
                                    else color = Colors.blue;

                                    return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ChoiceChip(
                                            label: Text(filter),
                                            selected: isSelected,
                                            onSelected: (selected) {
                                                if (selected) {
                                                    setState(() {
                                                        _currentFilter = filter;
                                                        _runFilter(null);
                                                    });
                                                }
                                            },
                                            selectedColor: color.withOpacity(0.1),
                                            backgroundColor: Colors.white,
                                            labelStyle: TextStyle(
                                                color: isSelected ? color : Colors.grey,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                            ),
                                            side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        ),
                                    );
                                }).toList(),
                            ),
                        ),

                        // BATCH PROCUREMENT BANNER (AMBANG BATAS)
                        if (_lowStockCount > 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.notification_important_rounded, color: Color(0xFFD97706), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$_lowStockCount produk di ambang batas kritis (≤ 5)',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                                      ),
                                      const Text(
                                        'Perlu belanja stok untuk besok.',
                                        style: TextStyle(fontSize: 10.5, color: Color(0xFFB45309)),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB45309),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: _openBatchProcurement,
                                  icon: const Icon(Icons.send_rounded, size: 12),
                                  label: const Text('Ajukan Semua', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // --- CONTENT LIST ---
                  Expanded(
                    child: _filteredList.isEmpty
                        ? Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                    Icon(Icons.search_off, size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text('Data tidak ditemukan', style: TextStyle(color: Colors.grey)),
                                ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredList.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _filteredList[index];
                              final productId = safeInt(item['product_id']);
                              final systemQty = safeInt(item['stok_sistem']); 
                              final terjual = safeInt(item['terjual_hari_ini']);
                              final productName = item['nama'] ?? '-'; 
                              final unit = item['unit'] ?? 'pcs';
                              final int cogs = safeInt(item['cogs']);
                              
                              if (productId == 0) return const SizedBox.shrink();

                              final currentStatus = _diffStatus[productId] ?? 'normal';
                              final difference = _diffValue[productId] ?? 0;
                              final diffColor = _getDiffColor(currentStatus);
                              final currentRealQty = int.tryParse(_qtyControllers[productId]?.text.trim() ?? '') ?? safeInt(item['stok_riil']);
                              final bool isLowStock = currentRealQty <= 5;
                              final bool isRequested = _procurementRequests.containsKey(productId);
                              
                              return Container(
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                          BoxShadow(
                                              color: Colors.black.withOpacity(0.04),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4)
                                          )
                                      ],
                                      border: currentStatus != 'normal' 
                                        ? Border.all(color: diffColor.withOpacity(0.5), width: 1.5)
                                        : null
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                          Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                  // ICON
                                                  Container(
                                                      padding: const EdgeInsets.all(10),
                                                      decoration: BoxDecoration(
                                                          color: Colors.blue.shade50,
                                                          shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(Icons.inventory_2, color: Colors.blue, size: 24),
                                                  ),
                                                  const SizedBox(width: 16),

                                                  // DETAILS
                                                  Expanded(
                                                      child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                              Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                              const SizedBox(height: 4),
                                                              Wrap(
                                                                  spacing: 6,
                                                                  runSpacing: 4,
                                                                  children: [
                                                                      _buildPill('Terjual: $terjual', Colors.orange.shade50, Colors.orange.shade800),
                                                                      if (cogs > 0)
                                                                          _buildPill('Modal: ${_formatCurrency(cogs)}', Colors.grey.shade100, Colors.grey.shade700),
                                                                  ],
                                                              ),
                                                              const SizedBox(height: 8),
                                                              Text.rich(
                                                                  TextSpan(
                                                                      text: 'Stok Sistem: ',
                                                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                                      children: [
                                                                          TextSpan(text: '$systemQty $unit', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))
                                                                      ]
                                                                  )
                                                              )
                                                          ],
                                                      ),
                                                  ),
                                                  
                                                  // INPUT
                                                  const SizedBox(width: 12),
                                                  Column(
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      children: [
                                                          SizedBox(
                                                              width: 80,
                                                              child: TextField(
                                                                  controller: _qtyControllers[productId],
                                                                  keyboardType: TextInputType.number,
                                                                  textAlign: TextAlign.center,
                                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                                                  onChanged: (val) => _calculateDifference(productId, systemQty, val),
                                                                  decoration: InputDecoration(
                                                                      hintText: '0',
                                                                      isDense: true,
                                                                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                                                      border: OutlineInputBorder(
                                                                          borderRadius: BorderRadius.circular(12),
                                                                          borderSide: BorderSide(color: Colors.grey.shade300)
                                                                      ),
                                                                      filled: true,
                                                                      fillColor: Colors.grey.shade50
                                                                  ),
                                                              ),
                                                          ),
                                                          if (difference != 0)
                                                              Padding(
                                                                  padding: const EdgeInsets.only(top: 8),
                                                                  child: Container(
                                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                      decoration: BoxDecoration(
                                                                          color: diffColor.withOpacity(0.1),
                                                                          borderRadius: BorderRadius.circular(6)
                                                                      ),
                                                                      child: Text(
                                                                          '${difference > 0 ? '-' : '+'}${difference.abs()}',
                                                                          style: TextStyle(color: diffColor, fontWeight: FontWeight.bold, fontSize: 12)
                                                                      ),
                                                                  ),
                                                              )
                                                      ],
                                                  )
                                              ],
                                          ),

                                          // --- PROCUREMENT CALLOUT / ACTION ---
                                          if (isRequested) ...[
                                              Container(
                                                  margin: const EdgeInsets.only(top: 12),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  decoration: BoxDecoration(
                                                      color: const Color(0xFFF0FDF4),
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(color: const Color(0xFFBBF7D0)),
                                                  ),
                                                  child: Row(
                                                      children: [
                                                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                              child: Text(
                                                                  'Pengajuan ${_procurementRequests[productId]!['qty']} $unit terkirim (Menunggu Approval Owner)',
                                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                                                              ),
                                                          ),
                                                      ],
                                                  ),
                                              ),
                                          ] else if (isLowStock) ...[
                                              Container(
                                                  margin: const EdgeInsets.only(top: 12),
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                      color: const Color(0xFFFFFBEB),
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                                  ),
                                                  child: Row(
                                                      children: [
                                                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                              child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                      Text(
                                                                          'Stok Kritis! Sisa $currentRealQty $unit (≤ 5)',
                                                                          style: const TextStyle(
                                                                              fontSize: 11.5,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: Color(0xFF92400E),
                                                                          ),
                                                                      ),
                                                                      const Text(
                                                                          'Disarankan restock untuk besok.',
                                                                          style: TextStyle(fontSize: 10, color: Color(0xFFB45309)),
                                                                      ),
                                                                  ],
                                                              ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          ElevatedButton.icon(
                                                              style: ElevatedButton.styleFrom(
                                                                  backgroundColor: const Color(0xFFD97706),
                                                                  foregroundColor: Colors.white,
                                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                  minimumSize: Size.zero,
                                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                              ),
                                                              onPressed: () => _openQuickProcurementSheet(context, item, currentRealQty),
                                                              icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                                                              label: const Text('Ajukan Belanja', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                          ),
                                                      ],
                                                  ),
                                              ),
                                          ] else ...[
                                              Padding(
                                                  padding: const EdgeInsets.only(top: 8),
                                                  child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                          InkWell(
                                                              onTap: () => _openQuickProcurementSheet(context, item, currentRealQty),
                                                              borderRadius: BorderRadius.circular(6),
                                                              child: Padding(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                                  child: Row(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      children: [
                                                                          Icon(Icons.add_shopping_cart_rounded, size: 13, color: Colors.blue.shade700),
                                                                          const SizedBox(width: 4),
                                                                          Text(
                                                                              '+ Ajukan Belanja',
                                                                              style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                                                                          ),
                                                                      ],
                                                                  ),
                                                              ),
                                                          ),
                                                      ],
                                                  ),
                                              ),
                                          ],
                                      ],
                                  ),
                              );
                            },
                          ),
                  ),

                  // --- TERJUAL INFO BAR ---
                  if (_soldProductsToday.isNotEmpty)
                    InkWell(
                        onTap: () => _showSoldProductsDetail(context),
                        child: Container(
                            width: double.infinity,
                            color: Colors.yellow.shade100,
                            padding: const EdgeInsets.all(12),
                            child: Row(
                                children: [
                                    const Icon(Icons.info_outline, size: 18, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(
                                            '${_soldProductsToday.length} jenis produk terjual hari ini. Klik untuk detail.',
                                            style: TextStyle(color: Colors.brown.shade700, fontSize: 12)
                                        )
                                    ),
                                    const Icon(Icons.arrow_right, color: Colors.brown)
                                ],
                            ),
                        ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, dynamic val, Color color) {
      return Expanded(
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.1))
              ),
              child: Column(
                  children: [
                      Text(val.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
                      const SizedBox(height: 2),
                      Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w500)),
                  ],
              ),
          ),
      );
  }

  Widget _buildPill(String text, Color bg, Color fg) {
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          child: Text(text, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
      );
  }
}