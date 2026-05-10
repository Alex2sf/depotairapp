import 'package:flutter/material.dart';
import 'api_service.dart';
import 'package:intl/intl.dart'; // Import ini untuk format currency (opsional, tapi bagus)

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
                              final stokAwal = safeInt(item['stok_awal_hari']);
                              final terjual = safeInt(item['terjual_hari_ini']);
                              final productName = item['nama'] ?? '-'; 
                              final unit = item['unit'] ?? 'pcs';
                              
                              if (productId == 0) return const SizedBox.shrink();

                              final currentStatus = _diffStatus[productId] ?? 'normal';
                              final difference = _diffValue[productId] ?? 0;
                              final diffColor = _getDiffColor(currentStatus);
                              
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
                                  child: Row(
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
                                                      Row(
                                                          children: [
                                                              _buildPill('Terjual: $terjual', Colors.orange.shade50, Colors.orange.shade800),
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