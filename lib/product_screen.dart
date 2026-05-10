import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart'; 
import 'package:intl/intl.dart'; 
import 'api_service.dart';
import 'cart_model.dart'; 
import 'checkout_screen.dart'; 
import 'notification_model.dart'; 
import 'order_history_screen.dart'; 

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ApiService _apiService = ApiService();
  
  List<dynamic> _products = [];        
  List<dynamic> _masterProducts = []; 
  bool _isLoading = true;

  final FocusNode _focusNode = FocusNode(); 
  String _barcodeBuffer = ''; 
  final TextEditingController _searchController = TextEditingController();
  
  bool _showLowStockOnly = false;
  String _selectedProductType = 'SEMUA';
  List<Map<String, dynamic>> _productTypeOptions = [{'value': 'SEMUA', 'label': 'Semua Kategori'}]; 

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _searchController.addListener(_runFilter); 
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.removeListener(_runFilter);
    _searchController.dispose(); 
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    
    final result = await _apiService.getProducts(); 

    if (mounted) {
      final List<dynamic> products = result?['data'] ?? [];
      final List<dynamic> typeOptionsRaw = result?['filter_options']?['product_types'] ?? [];

      setState(() {
        _masterProducts = products;   
        
        if (typeOptionsRaw.isNotEmpty) {
           // Mapping agar label lebih rapi
            _productTypeOptions = typeOptionsRaw.map((e) => e as Map<String, dynamic>).toList(); 
            // Tambahkan opsi 'SEMUA' di depan jika belum ada
            if (!_productTypeOptions.any((o) => o['value'] == 'SEMUA')) {
               _productTypeOptions.insert(0, {'value': 'SEMUA', 'label': 'Semua'});
            }
        } else {
            _productTypeOptions = [{'value': 'SEMUA', 'label': 'Semua'}];
        }
        
        if (!_productTypeOptions.any((o) => o['value'] == _selectedProductType)) {
            _selectedProductType = 'SEMUA';
        }

        _runFilter();         
        _isLoading = false;
      });
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  void _runFilter() {
    String keyword = _searchController.text.toLowerCase();
    List<dynamic> results = _masterProducts;

    if (_showLowStockOnly) {
        results = results.where((product) => product['low_stock'] == true).toList();
    }
    
    if (_selectedProductType != 'SEMUA') {
        final targetType = _selectedProductType.toLowerCase();
        results = results.where((product) => 
            product['product_type'].toString().toLowerCase() == targetType).toList();
    }

    if (keyword.isNotEmpty) {
      results = results.where((product) {
        final name = product['name'].toString().toLowerCase();
        final sku = product['sku']?.toString().toLowerCase() ?? ''; 
        return name.contains(keyword) || sku.contains(keyword);
      }).toList();
    }
    
    if (mounted) {
      setState(() {
        _products = results; 
      });
    }
  }

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_barcodeBuffer.isNotEmpty) {
          _findAndAddToCart(_barcodeBuffer); 
          _barcodeBuffer = ''; 
        }
      } 
      else if (event.character != null && event.character!.isNotEmpty) {
        if (!event.isControlPressed && !event.isAltPressed && !event.isMetaPressed) {
           _barcodeBuffer += event.character!;
        }
      }
    }
  }

  void _findAndAddToCart(String scannedSku) {
    try {
      final product = _masterProducts.firstWhere(
        (p) => p['sku']?.toString().trim() == scannedSku.trim(),
        orElse: () => null,
      );

      if (product != null) {
        final cart = Provider.of<CartModel>(context, listen: false);
        cart.addItem(product);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan Berhasil: ${product['name']} (+1)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SKU "$scannedSku" tidak ditemukan!'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Error scan: $e");
    }
  }

  void _showOpnameDialog(Map<String, dynamic> product) {
    final TextEditingController controller = TextEditingController(text: product['stock'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Opname: ${product['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stok Sistem: ${product['stock']} ${product['unit']}'),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Masukkan Real Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final realQty = int.tryParse(controller.text);
                if (realQty == null || realQty < 0) return;

                Navigator.of(context).pop(); 

                final success = await _apiService.postSingleOpname(
                  product['id'] as int, 
                  realQty,
                  'Quick Opname via POS',
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Stok diperbarui!' : 'Gagal update stok.')),
                  );
                   _fetchProducts(); 
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartModel>(context); 
    
    return Scaffold(
      backgroundColor: Colors.grey.shade100, // Background agak abu biar card pop-up
      appBar: AppBar(
        title: const Text('Katalog Produk', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
        actions: [
           // --- NOTIF BUTTON ---
           Consumer<NotificationModel>(
             builder: (context, notif, child) {
               return Stack(
                 children: [
                   IconButton(
                     icon: const Icon(Icons.notifications_none_rounded, size: 28),
                     onPressed: () {
                        notif.markAsRead(); 
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const OrderHistoryScreen()),
                        );
                     },
                   ),
                   if (notif.unreadCount > 0)
                     Positioned(
                       right: 12,
                       top: 12,
                       child: Container(
                         padding: const EdgeInsets.all(4),
                         decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                         child: Text(
                           '${notif.unreadCount}',
                           style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                         ),
                       ),
                     )
                 ],
               );
             },
           ),
           // --- CART BUTTON ---
           Padding(
             padding: const EdgeInsets.only(right: 8.0),
             child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined, size: 28),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const CheckoutScreen()),
                      );
                    },
                  ),
                  if (cart.totalItems > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          cart.totalItems.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                ],
              ),
           ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode, 
        autofocus: true,       
        onKey: _handleKey,     
        child: Column(
          children: [
            // --- BAGIAN ATAS: SEARCH & CHIPS ---
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SEARCH BAR
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari nama, SKU, atau scan...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () {
                            _searchController.clear();
                            _runFilter();
                          })
                        : null,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // KATEGORI CHIPS (SCROLLABLE)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _productTypeOptions.map((option) {
                        final isSelected = _selectedProductType == option['value'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(option['label']),
                            selected: isSelected,
                            onSelected: (bool selected) {
                              if (selected) {
                                setState(() {
                                  _selectedProductType = option['value'];
                                  _runFilter();
                                });
                              }
                            },
                            selectedColor: Colors.blue.shade100,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.blue.shade900 : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? Colors.blue : Colors.grey.shade300,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            
            // --- GRID PRODUK ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.search_off, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Produk tidak ditemukan', style: TextStyle(color: Colors.grey, fontSize: 16)),
                            ],
                          ),
                        )
                      : GridView.builder( 
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, 
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.65, // Fix Overflow: Kartu lebih tinggi lagi
                          ),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            final isLowStock = product['low_stock'] == true;
                            
                            // Fix URL localhost -> Android Emulator
                            String? imageUrl = product['image_url'];
                            if (imageUrl != null && imageUrl.contains('localhost')) {
                              imageUrl = imageUrl.replaceFirst('localhost', '10.0.2.2');
                            }

                            final priceFormatted = NumberFormat.currency(
                              locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0
                            ).format(product['price']);

                            return InkWell(
                              onTap: () { 
                                cart.addItem(product);
                                HapticFeedback.lightImpact(); 
                              },
                              onLongPress: () => _showOpnameDialog(product), 
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // GAMBAR
                                    Expanded(
                                      flex: 3,
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                            child: Container(
                                              width: double.infinity,
                                              color: Colors.grey.shade100,
                                              child: (imageUrl != null && imageUrl.isNotEmpty)
                                                  ? Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_,__,___) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                                                    )
                                                  : Center(
                                                      child: Text(
                                                        product['sku'] ?? 'NO IMG', 
                                                        style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          if (isLowStock)
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Text('STOK TIPIS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    
                                    // INFO PRODUK
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Nama
                                            Text(
                                              product['name'],
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            
                                            const Spacer(), // Ganti SpaceBetween dengan Spacer agar fleksibel

                                            // Harga & Stok
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  priceFormatted,
                                                  style: const TextStyle(
                                                    color: Colors.black87, 
                                                    fontWeight: FontWeight.bold, 
                                                    fontSize: 15
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Stok: ${product['stock']} ${product['unit'] ?? ''}',
                                                      style: TextStyle(
                                                        fontSize: 12, 
                                                        color: isLowStock ? Colors.red : Colors.grey.shade600
                                                      ),
                                                    ),
                                                    // Tombol Add Mini
                                                    Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.shade50,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(Icons.add, size: 16, color: Colors.blue),
                                                    )
                                                  ],
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _showLowStockOnly ? FloatingActionButton.extended(
        onPressed: () => setState(() { _showLowStockOnly = false; _runFilter(); }),
        label: const Text('Show All'),
        icon: const Icon(Icons.filter_list_off),
        backgroundColor: Colors.black87,
      ) : null,
    );
  }
}