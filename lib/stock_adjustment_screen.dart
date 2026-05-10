import 'package:flutter/material.dart';
import 'api_service.dart';

class StockAdjustmentScreen extends StatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    final data = await _apiService.getProducts();
    if (data != null && data['success'] == true) {
      if (mounted) {
        setState(() {
          _products = List<dynamic>.from(data['data']);
          _runFilter();
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil data produk.')),
        );
      }
    }
  }

  void _runFilter() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredProducts = List.from(_products);
      } else {
        _filteredProducts = _products.where((p) {
          final name = p['name'].toString().toLowerCase();
          final sku = (p['sku'] ?? '').toString().toLowerCase();
          final query = _searchQuery.toLowerCase();
          return name.contains(query) || sku.contains(query);
        }).toList();
      }
    });
  }

  void _showAdjustSheet(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow full height
      backgroundColor: Colors.transparent,
      builder: (context) => _AdjustStockSheet(
        product: product,
        onSuccess: () {
          _fetchProducts(); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stok berhasil diperbarui!'), backgroundColor: Colors.green),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], 
      body: Column(
        children: [
          // CUSTOM GRADIENT HEADER
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              children: [
                // Title Row
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Kelola Stok',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 40), // Balance the back button
                  ],
                ),
                const SizedBox(height: 20),
                
                // Search Field inside Header
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Cari Produk atau SKU...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _runFilter();
                              });
                            },
                          )
                        : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _runFilter();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // LIST CONTENT
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_late_outlined, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('Produk tidak ditemukan', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 40),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final p = _filteredProducts[index];
                          final stock = p['stock'] ?? 0;
                          final unit = p['unit'] ?? 'pcs';
                          final isLowStock = stock <= 10;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: () => _showAdjustSheet(p),
                               borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // AVATAR
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: isLowStock ? Colors.orange[50] : Colors.blue[50],
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: Center(
                                          child: Text(
                                            p['name'][0].toUpperCase(),
                                            style: TextStyle(
                                              color: isLowStock ? Colors.orange[800] : Colors.blue[800],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 22,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // DETAILS
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p['name'],
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'SKU: ${p['sku'] ?? '-'}',
                                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // STOCK
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$stock',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: isLowStock ? Colors.deepOrange : Colors.green[700],
                                            ),
                                          ),
                                          Text(
                                            unit,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// === BOTTOM SHEET WIDGET ===
class _AdjustStockSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onSuccess;

  const _AdjustStockSheet({required this.product, required this.onSuccess});

  @override
  State<_AdjustStockSheet> createState() => _AdjustStockSheetState();
}

class _AdjustStockSheetState extends State<_AdjustStockSheet> {
  final ApiService _apiService = ApiService();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  String _selectedReason = 'RESTOCK';
  String _direction = 'in'; 
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _reasons = [
    {'id': 'RESTOCK', 'label': 'Restock', 'icon': Icons.add_business, 'color': Colors.green},
    {'id': 'DAMAGE', 'label': 'Rusak', 'icon': Icons.broken_image, 'color': Colors.red},
    {'id': 'RETURN', 'label': 'Retur', 'icon': Icons.assignment_return, 'color': Colors.blue},
    {'id': 'ADJUSTMENT', 'label': 'Manual', 'icon': Icons.tune, 'color': Colors.orange},
  ];

  @override
  void initState() {
    super.initState();
    _qtyController.text = '';
  }

  void _selectReason(String reason) {
    setState(() {
      _selectedReason = reason;
      if (reason == 'RESTOCK' || reason == 'RETURN') _direction = 'in';
      if (reason == 'DAMAGE') _direction = 'out';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20, // Avoid Keyboard
        left: 24,
        right: 24,
        top: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.only(bottom: 20),
            ),
          ),
          
          Text(
            widget.product['name'],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            maxLines: 2,
          ),
          const SizedBox(height: 5),
          Text(
            'Sisa stok: ${widget.product['stock']} ${widget.product['unit']}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 25),

          // Reason Selector
          const Text('Pilih Alasan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _reasons.map((r) {
                final isSelected = _selectedReason == r['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    showCheckmark: false,
                    label: Text(r['label']),
                    avatar: Icon(r['icon'], size: 16, color: isSelected ? Colors.white : r['color']),
                    selected: isSelected,
                    onSelected: (_) => _selectReason(r['id']),
                    selectedColor: r['color'],
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey[300]!),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 20),

          // Manual Adjustment Toggle
          if (_selectedReason == 'ADJUSTMENT') ...[
             const Text('Jenis Penyesuaian', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
             const SizedBox(height: 10),
             Row(
               children: [
                 Expanded(child: _buildRadioBtn('Masuk (+)', 'in', Colors.green)),
                 const SizedBox(width: 12),
                 Expanded(child: _buildRadioBtn('Keluar (-)', 'out', Colors.red)),
               ],
             ),
             const SizedBox(height: 20),
          ],

          // Quantity Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Jumlah',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Quick Buttons
              Wrap(
                spacing: 8,
                children: ['+1', '+5', '+10'].map((val) => _buildPresetBtn(val)).toList(),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Notes Input
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'Tambahkan catatan jika perlu...',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.edit_note, color: Colors.grey),
            ),
          ),
          
          const SizedBox(height: 24),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                elevation: 5,
                shadowColor: Colors.blue.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('SIMPAN PERUBAHAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildRadioBtn(String label, String val, Color activeColor) {
    final isSelected = _direction == val;
    return InkWell(
      onTap: () => setState(() => _direction = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.1) : Colors.white,
          border: Border.all(color: isSelected ? activeColor : Colors.grey[300]!, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? activeColor : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetBtn(String val) {
    return InkWell(
      onTap: () {
        int current = int.tryParse(_qtyController.text) ?? 0;
        int add = int.parse(val.replaceAll('+', ''));
        setState(() => _qtyController.text = (current + add).toString());
      },
      child: Container(
        width: 45,
        height: 55, // Match input height
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[100]!),
        ),
        child: Center(
          child: Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800])),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_qtyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi jumlah dulu ya!')));
      return;
    }
    int qty = int.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jumlah tidak boleh 0!')));
      return;
    }

    setState(() => _isSubmitting = true);

    final res = await _apiService.adjustStock(
      productId: widget.product['id'],
      quantity: qty,
      reason: _selectedReason,
      notes: _notesController.text,
      direction: _selectedReason == 'ADJUSTMENT' ? _direction : null,
    );

    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      if (mounted) Navigator.pop(context);
      widget.onSuccess();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']), backgroundColor: Colors.red),
        );
      }
    }
  }
}
