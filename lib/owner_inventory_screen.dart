import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

class OwnerInventoryScreen extends StatefulWidget {
  const OwnerInventoryScreen({super.key});

  @override
  State<OwnerInventoryScreen> createState() => _OwnerInventoryScreenState();
}

class _OwnerInventoryScreenState extends State<OwnerInventoryScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? _inventoryData;
  List<dynamic> _inventoryList = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchInventoryData();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInventoryData() async {
    setState(() => _isLoading = true);
    final result = await _apiService.getOwnerInventory(search: _searchQuery);
    if (mounted) {
      setState(() {
        _inventoryData = result;
        _inventoryList = result?['data'] ?? [];
        _isLoading = false;
      });
    }
  }
  
  String _formatCurrency(num amount) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
           // HEADER
           Container(
             padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
             decoration: BoxDecoration(
               gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade600], begin: Alignment.topLeft, end: Alignment.bottomRight),
               boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]
             ),
             child: Column(
               children: [
                 const Text("Stok Analitik", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 20),
                 // Search Bar
                 TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                       filled: true,
                       fillColor: Colors.white.withOpacity(0.2),
                       hintText: "Cari Produk / SKU ...",
                       hintStyle: TextStyle(color: Colors.blue.shade100),
                       prefixIcon: const Icon(Icons.search, color: Colors.white),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                       contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                       isDense: true
                    ),
                    onSubmitted: (v) { setState(()=>_searchQuery=v); _fetchInventoryData(); },
                 )
               ],
             ),
           ),

           // SUMMARY & LIST
           Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchInventoryData,
                child: Column(
                  children: [
                     if (_inventoryData != null) _buildSummary(),
                     Expanded(
                       child: _isLoading 
                          ? const Center(child: CircularProgressIndicator()) 
                          : _inventoryList.isEmpty 
                              ? const Center(child: Text("Data tidak ditemukan"))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _inventoryList.length,
                                  itemBuilder: (context, index) => _buildItemCard(_inventoryList[index]),
                                ),
                     )
                  ],
                ),
              ),
           )
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final ringkasan = _inventoryData?['ringkasan'] ?? {};
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
           Expanded(child: _buildSummaryCard("Produk Kurang", ringkasan['produk_kurang'] ?? 0, Colors.red)),
           const SizedBox(width: 12),
           Expanded(child: _buildSummaryCard("Produk Lebih", ringkasan['produk_lebih'] ?? 0, Colors.green)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, num count, Color color) {
     return Container(
       padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
       decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
       child: Column(
         children: [
            Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
         ],
       ),
     );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
     bool isKurang = item['status'] == 'kurang';
     bool isLebih = item['status'] == 'lebih';
     Color statusColor = isKurang ? Colors.red : (isLebih ? Colors.green : Colors.grey);
     
     return Container(
       margin: const EdgeInsets.only(bottom: 12),
       decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset:const Offset(0,2))]
       ),
       child: Padding(
         padding: const EdgeInsets.all(16),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Expanded(child: Text(item['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                       child: Text(item['status'].toString().toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                    )
                 ],
              ),
              const SizedBox(height: 4),
              Text("SKU: ${item['sku']}", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   _buildStat("Stok Sistem", item['stok_sistem'].toString()),
                   _buildStat("Stok Riil", item['stok_riil'].toString()),
                   _buildStat("Selisih", "${item['selisih']} ${item['unit']}", color: statusColor),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      const Text("Nilai Selisih:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(_formatCurrency(item['nilai_selisih'] ?? 0), style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
                   ],
                ),
              )
           ],
         ),
       ),
     );
  }

  Widget _buildStat(String label, String val, {Color color = Colors.black87}) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
       ],
     );
  }
}