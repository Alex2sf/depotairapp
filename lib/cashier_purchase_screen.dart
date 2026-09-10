import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class CashierPurchaseScreen extends StatefulWidget {
  const CashierPurchaseScreen({super.key});

  @override
  State<CashierPurchaseScreen> createState() => _CashierPurchaseScreenState();
}

class _CashierPurchaseScreenState extends State<CashierPurchaseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  // Form State
  final _formKey = GlobalKey<FormState>();
  String _category = 'STOCK'; // 'STOCK' or 'OPERATIONAL'
  int? _selectedProductId;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  File? _proofImage;

  bool _isLoading = false;
  bool _isFetchingProducts = true;
  List<dynamic> _products = [];
  int _currentCashierBalance = 0;

  // History State
  bool _isLoadingHistory = true;
  List<dynamic> _historyList = [];

  // Suggestion chips untuk operasional
  final List<String> _opSuggestions = [
    'Beli Bensin Kurir',
    'Token Listrik',
    'Air Galon Konsumsi',
    'Sapu / Kain Pel',
    'Makan Siang Karyawan',
    'Lain-lain'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        _fetchHistory();
      }
    });
    _fetchInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _qtyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isFetchingProducts = true);

    final balanceResult = await _apiService.getCashDashboard();
    final productData = await _apiService.getProducts();

    if (mounted) {
      if (balanceResult != null && balanceResult['success'] == true) {
        _currentCashierBalance = balanceResult['kas_kasir'] ?? 0;
      }

      if (productData != null && productData['success'] == true) {
        _products = List<dynamic>.from(productData['data'] ?? []);
        if (_products.isNotEmpty) {
          _selectedProductId = _products.first['id'];
        }
      }

      setState(() => _isFetchingProducts = false);
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoadingHistory = true);
    final res = await _apiService.getCashierPurchases();
    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        if (res != null && res['success'] == true) {
          _historyList = res['data'] ?? [];
        }
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _proofImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih foto: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ambil Bukti Nota / Belanjaan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageOption(
                      icon: Icons.camera_alt,
                      label: 'Kamera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    _buildImageOption(
                      icon: Icons.photo_library,
                      label: 'Galeri',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: Colors.blue.shade800),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
          ],
        ),
      ),
    );
  }

  void _formatInputCurrency(String value) {
    if (value.isEmpty) return;
    String clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    double number = double.parse(clean);
    String formatted = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(number).trim();

    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _submitPurchase() async {
    if (!_formKey.currentState!.validate()) return;

    final cleanAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(cleanAmount) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal belanja harus lebih dari 0!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (amount > _currentCashierBalance && _currentCashierBalance > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Saldo Laci Tidak Cukup?'),
          content: Text(
            'Uang di laci tercatat Rp ${NumberFormat.currency(locale: "id_ID", symbol: "", decimalDigits: 0).format(_currentCashierBalance)}.\nBelanja: Rp ${NumberFormat.currency(locale: "id_ID", symbol: "", decimalDigits: 0).format(amount)}.\nTetap lanjutkan?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tetap Lanjut', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    int? qty;
    if (_category == 'STOCK') {
      qty = int.tryParse(_qtyController.text) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jumlah barang belanja harus lebih dari 0!'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final res = await _apiService.postCashierPurchase(
      category: _category,
      amount: amount,
      description: _descController.text.trim(),
      productId: _category == 'STOCK' ? _selectedProductId : null,
      quantity: _category == 'STOCK' ? qty : null,
      proofImagePath: _proofImage?.path,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      final success = res['success'] == true;
      final message = res['message'] ?? 'Respon diterima';

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Reset Form
        _amountController.clear();
        _qtyController.clear();
        _descController.clear();
        setState(() {
          _proofImage = null;
        });

        // Refresh Saldo & Produk
        _fetchInitialData();

        // Pindah ke tab Riwayat
        _tabController.animateTo(1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showProofZoomDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text('Gagal memuat gambar', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Belanja Kas Laci', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelColor: Colors.white70,
          labelColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Catat Belanja'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Riwayat Belanja'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFormTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  // --- TAB 1: FORM PENCATATAN BELANJA ---
  Widget _buildFormTab() {
    final isStock = _category == 'STOCK';
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KARTU SALDO LACI SAAT INI
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.point_of_sale, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Saldo Kas Laci Tersedia', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormatter.format(_currentCashierBalance),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // TOGGLE KATEGORI BELANJA
            const Text('Kategori Belanja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildCategoryToggle('Stok Barang Jualan', 'STOCK', Icons.inventory_2, Colors.teal),
                  ),
                  Expanded(
                    child: _buildCategoryToggle('Operasional Toko', 'OPERATIONAL', Icons.storefront, Colors.orange.shade800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SECTION KHUSUS STOK BARANG
            if (isStock) ...[
              const Text('Pilih Barang yang Dibeli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 8),
              if (_isFetchingProducts)
                const Center(child: CircularProgressIndicator())
              else if (_products.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Belum ada data produk tersedia di sistem.', style: TextStyle(color: Colors.orange)),
                )
              else
                DropdownButtonFormField<int>(
                  value: _selectedProductId,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                  items: _products.map((p) {
                    return DropdownMenuItem<int>(
                      value: p['id'] as int,
                      child: Row(
                        children: [
                          Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('(Stok: ${p['stock']} ${p['unit']})', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedProductId = val;
                      final selectedProd = _products.firstWhere((p) => p['id'] == val, orElse: () => null);
                      if (selectedProd != null && _descController.text.isEmpty) {
                        _descController.text = 'Beli ${selectedProd['name']}';
                      }
                    });
                  },
                ),
              const SizedBox(height: 16),

              // INPUT JUMLAH BARANG (QUANTITY)
              const Text('Jumlah Barang Dibeli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Contoh: 50',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                        suffixText: _products.firstWhere((p) => p['id'] == _selectedProductId, orElse: () => null)?['unit'] ?? 'pcs',
                      ),
                      validator: (val) {
                        if (isStock && (val == null || val.isEmpty)) return 'Wajib diisi';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Quick Qty Preset
                  ...['+10', '+50', '+100'].map((preset) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: InkWell(
                      onTap: () {
                        int cur = int.tryParse(_qtyController.text) ?? 0;
                        int add = int.parse(preset.replaceAll('+', ''));
                        setState(() => _qtyController.text = (cur + add).toString());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Text(preset, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                      ),
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // NOMINAL UANG BELANJA (DIPOTONG DARI LACI)
            const Text('Total Uang Belanja (Dari Laci)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.red.shade700),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                hintText: '0',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
              onChanged: _formatInputCurrency,
              validator: (val) => val == null || val.isEmpty ? 'Nominal wajib diisi' : null,
            ),
            const SizedBox(height: 20),

            // KETERANGAN / DESKRIPSI
            const Text('Keterangan / Catatan Belanja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 8),

            // Chips rekomendasi operasional
            if (!isStock) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _opSuggestions.map((s) => ActionChip(
                  label: Text(s),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade300),
                  labelStyle: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                  onPressed: () => setState(() => _descController.text = s),
                )).toList(),
              ),
              const SizedBox(height: 10),
            ],

            TextFormField(
              controller: _descController,
              decoration: InputDecoration(
                hintText: isStock ? 'Contoh: Beli tutup galon dari toko sebelah' : 'Keterangan pengeluaran operasional...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Keterangan wajib diisi' : null,
            ),
            const SizedBox(height: 20),

            // UPLOAD FOTO BUKTI / NOTA
            const Text('Foto Nota / Struk / Barang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _showImageSourceDialog,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200, width: 1.5, style: BorderStyle.solid),
                ),
                child: _proofImage != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_proofImage!, width: double.infinity, height: 140, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 16,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                onPressed: () => setState(() => _proofImage = null),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 40, color: Colors.blue.shade600),
                          const SizedBox(height: 8),
                          Text('Ketuk untuk Ambil Foto Nota / Struk', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('(Sangat disarankan untuk pembukuan)', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 30),

            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: Colors.blue.withOpacity(0.4),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text(
                        'SIMPAN TRANSAKSI BELANJA',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryToggle(String title, String val, IconData icon, Color color) {
    final isSelected = _category == val;
    return GestureDetector(
      onTap: () => setState(() => _category = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? color : Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: RIWAYAT BELANJA KASIR ---
  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyList.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchHistory,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Belum ada riwayat belanja dari kasir', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text('Tarik ke bawah untuk memuat ulang', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historyList.length,
        itemBuilder: (context, index) {
          final item = _historyList[index];
          final isStock = item['category'] == 'STOCK';
          final amount = item['amount'] ?? 0;
          final proofUrl = item['proof_image_url'];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER: KATEGORI & WAKTU
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isStock ? Colors.teal.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isStock ? Colors.teal.shade100 : Colors.orange.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(isStock ? Icons.inventory_2 : Icons.storefront, size: 14, color: isStock ? Colors.teal.shade800 : Colors.orange.shade800),
                            const SizedBox(width: 4),
                            Text(
                              isStock ? 'BELANJA STOK' : 'OPERASIONAL',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isStock ? Colors.teal.shade800 : Colors.orange.shade800),
                            ),
                          ],
                        ),
                      ),
                      Text(item['created_at'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // KONTEN: NAMA BARANG ATAU KETERANGAN
                  if (isStock && item['product_name'] != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['product_name'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            '+${item['quantity']} ${item['unit']}',
                            style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  Text(item['description'] ?? '-', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // FOOTER: BIAYA & BUKTI FOTO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Biaya (Kas Laci):', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                          Text(
                            currencyFormatter.format(amount),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade700),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text('Oleh: ${item['cashier_name'] ?? 'Kasir'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          if (proofUrl != null) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showProofZoomDialog(proofUrl),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    proofUrl,
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, _, __) => const Icon(Icons.receipt, size: 24, color: Colors.blue),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
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
  }
}
