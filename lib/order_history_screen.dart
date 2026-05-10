import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode if needed
import 'dart:async'; // FOR TIMER
import 'dart:ui'; // FOR FontFeature
import 'api_service.dart';
import 'package:intl/intl.dart'; 
import 'order_detail_screen.dart'; 
import 'widgets/order_timer_widget.dart'; 

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final ApiService _apiService = ApiService();
  // late TabController _tabController; // HAPUS INI
  
  // Data
  List<dynamic> _allOrders = [];
  bool _isLoading = true;
  
  // Filters
  String _searchQuery = '';
  String? _filterStatus; // ADDED: Status Filter
  // Default FILTER HARI INI
  DateTime? _startDate = DateTime.now(); 
  DateTime? _endDate = DateTime.now();
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // _tabController = TabController(length: 3, vsync: this); // HAPUS INI
    _fetchOrders();
  }

  @override
  void dispose() {
    // _tabController.dispose(); // HAPUS INI
    _searchController.dispose();
    super.dispose();
  }

  // --- LOGIC FETCHING (LOAD ALL FOR TODAY/RANGE & FILTER CLIENT SIDE) ---
  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);

    final String? startStr = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null;
    final String? endStr;
    if (_endDate != null) {
       // Backend uses whereDate, so we just send YYYY-MM-DD
       endStr = DateFormat('yyyy-MM-dd').format(_endDate!);
    } else {
       endStr = null;
    }

    // Kita ambil semua data (tanpa pagination kecil, misal page 1 tapi limit besar, 
    // atau loop page kalau API pagination-nya strict. 
    // Untuk daily order biasanya < 100, jadi kita asumsikan 1 kali fetch cukup atau kita bikin recursive fetch all)
    // SEMENTARA: Kita fetch basic page 1. Jika butuh "Load More", UI TabBarView agak tricky dengan single list source.
    // SOLUSI PRO: Fetch "Semua" dari API tanpa pagination (kalau API support) atau just fetch page 1-5 loop.
    // API `getOrderHistory` support pagination. Kita handle standar dulu (page 1).
    
    // Better strategy for "Dashboard" style: Fetch as much as possible or just show page 1 sorted.
    // User request: "Yang buru-buru dikirim". This implies we need ALL pending delivery orders.
    // Let's assume standard fetch is enough for now, but we'll try to get more items if possible.
    
    final result = await _apiService.getOrderHistory(
      page: 1, 
      search: _searchQuery,
      startDate: startStr,
      endDate: endStr,
    );
    
    // Note: Jika order banyak sekali (>20), pagination akan memotong data.
    // Idealnya backend punya endpoint khusus "daily orders dashboard" tanpa pagination.
    // Tapi kita pakai yang ada dulu.
    
    if (mounted) {
       setState(() {
         _isLoading = false;
         if (result != null) {
            _allOrders = result['data'] ?? [];
         } else {
            _allOrders = [];
            ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Gagal koneksi ke server. Pastikan API jalan!'), backgroundColor: Colors.red),
            );
         }
       });
    }
  }

  // --- LOGIC FILTERING TABS ---
  List<dynamic> _getFilteredList(int tabIndex) {
      if (_allOrders.isEmpty) return [];

      List<dynamic> filtered = [];
      
      switch (tabIndex) {
          case 0: // SEMUA
             filtered = List.from(_allOrders);
             break;
          case 1: // PICK UP
             filtered = _allOrders.where((o) => (o['order_type'] ?? 'SELF_PICKUP') == 'SELF_PICKUP').toList();
             break;
          case 2: // DELIVERY (URGENT SORT)
             filtered = _allOrders.where((o) => (o['order_type'] ?? 'SELF_PICKUP') == 'DELIVERY').toList();
             // SORTING: Waktu kirim terdekat (ASC)
             filtered.sort((a, b) {
                 String? timeA = a['delivery_scheduled_at'];
                 String? timeB = b['delivery_scheduled_at'];
                 if (timeA == null && timeB == null) return 0;
                 if (timeA == null) return 1; // Null di belakang
                 if (timeB == null) return -1;
                 return timeA.compareTo(timeB);
             });
             break;
          case 3: // COMPLETE
             filtered = _allOrders.where((o) {
                final s = (o['status'] ?? '').toUpperCase();
                return s == 'COMPLETE' || s == 'DONE' || s == 'DELIVERED';
             }).toList();
             break;
      }
      
      // APPLY STATUS FILTER (ON TOP OF TABS)
      if (_filterStatus != null) {
          filtered = filtered.where((o) {
              final s = (o['status'] ?? '').toString().toUpperCase();
              return s == _filterStatus;
          }).toList();
      }

      return filtered;
  }

  // --- UTILS FORMAT ---
  Color _getStatusColor(String status) {
      switch (status.toUpperCase()) {
          case 'COMPLETED': case 'DONE': case 'PAID': case 'DELIVERED': return Colors.green;
          case 'CANCELLED': case 'VOID': return Colors.red;
          case 'PROCESSING': case 'ON_PROCESS': return Colors.orange;
          case 'PENDING': case 'NEW': return Colors.amber.shade700;
          case 'DRAFT': return Colors.black;
          case 'READY': case 'READY_FOR_PICKUP': return Colors.purple;
          default: return Colors.blueGrey;
      }
  }

  String _formatDate(String? dateStr) {
      if (dateStr == null || dateStr == '-') return '-';
      if (dateStr.toLowerCase() == 'sekarang') return 'Sekarang'; // Handle literal 'Sekarang' if needed, but we try to replace it in UI
      try {
          // Attempt standard parsing
          final dt = DateTime.tryParse(dateStr) ?? DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateStr);
          return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal()); 
      } catch(e) { 
          // Try other formats if needed
          try {
             final dt = DateFormat('d MMM yyyy HH:mm').parse(dateStr);
             return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
          } catch(_) {
             return dateStr; 
          }
      }
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
       context: context, 
       initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
       firstDate: DateTime(2024), 
       lastDate: DateTime.now().add(const Duration(days: 365))
    );
    if (picked != null) {
        setState(() => isStart ? _startDate = picked : _endDate = picked);
        _fetchOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Order Harian', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          bottom: const TabBar(
              isScrollable: true, // Biar muat 4 tab
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: [
                  Tab(text: "Semua"),
                  Tab(text: "Self Pick Up"),
                  Tab(text: "Delivery 🛵"),
                  Tab(text: "Complete ✅"),
              ],
          ),
        ),
        body: Column(
          children: [
              _buildFilterHeader(),
              Expanded(
                  child: _isLoading 
                      ? const Center(child: CircularProgressIndicator()) 
                      : TabBarView(
                          children: [
                             _buildOrderList(0),
                             _buildOrderList(1),
                             _buildOrderList(2),
                             _buildOrderList(3),
                          ],
                      ),
              )
          ],
        )
      ),
    );
  }

  Widget _buildFilterHeader() {
      bool isToday = _startDate != null && _endDate != null && 
                     _startDate!.day == DateTime.now().day && 
                     _endDate!.day == DateTime.now().day;
      
      return Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                   hintText: 'Cari Pelanggan / Order #...',
                   prefixIcon: const Icon(Icons.search),
                   isDense: true,
                   contentPadding: const EdgeInsets.all(10),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                   filled: true,
                   fillColor: Colors.grey.shade100
                ),
                onSubmitted: (v) { _searchQuery = v; _fetchOrders(); },
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(isToday ? "📅 HARI INI" : "📅 Mode Filter Tanggal", style: TextStyle(fontWeight: FontWeight.bold, color: isToday ? Colors.green : Colors.black)),
                  Row(children: [
                      InkWell(
                         onTap: () => _selectDate(true),
                         child: _dateChip(_startDate, "Dari"),
                      ),
                      const Text(" - "),
                      InkWell(
                         onTap: () => _selectDate(false),
                         child: _dateChip(_endDate, "Sampai"),
                      ),
                      IconButton(icon: const Icon(Icons.refresh, color: Colors.blue), onPressed: _fetchOrders)
                  ])
              ]),
              const SizedBox(height: 12),
              // STATUS FILTER CHIPS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                   children: [
                       _statusChip('DRAFT', 'Draft', Colors.grey),
                       const SizedBox(width: 8),
                       _statusChip('READY', 'Ready', Colors.purple),
                       const SizedBox(width: 8),
                       _statusChip('ON_DELIVERY', 'Sedang Jalan', Colors.orange),
                       const SizedBox(width: 8),
                       _statusChip('COMPLETE', 'Selesai', Colors.green),
                   ],
                ),
              )
          ]),
      );
  }

  Widget _statusChip(String statusKey, String label, Color color) {
      bool isSelected = _filterStatus == statusKey;
      return FilterChip(
         label: Text(label), 
         selected: isSelected,
         onSelected: (val) {
             setState(() => _filterStatus = val ? statusKey : null);
         },
         checkmarkColor: Colors.white,
         selectedColor: color,
         labelStyle: TextStyle(color: isSelected ? Colors.white : color, fontWeight: FontWeight.bold),
         backgroundColor: Colors.white,
         shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(20),
             side: BorderSide(color: color.withOpacity(0.5))
         ),
      );
  }
  
  Widget _dateChip(DateTime? date, String label) {
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
          child: Text(date == null ? label : DateFormat('dd/MM').format(date), style: const TextStyle(fontSize: 12)),
      );
  }

  DateTime? _parseDateForTimer(String? dateStr) {
      if (dateStr == null || dateStr == '-') return null;
      try {
          return DateTime.parse(dateStr);
      } catch (e) {
          try {
             // Try dd/MM/yyyy HH:mm (e.g. 14/01/2026 15:30)
             // Assumption: This usually comes from raw created_at which might be UTC. 
             // If we find the time is wildly off (e.g. > 6 hours for a fresh order), we might need to .toLocal() from UTC.
             // For now, let's parse as is.
             return DateFormat('dd/MM/yyyy HH:mm').parse(dateStr); 
          } catch (e2) {
             try {
                // Try d MMM yyyy HH:mm (e.g. 14 Jan 2026 15:30)
                return DateFormat('d MMM yyyy HH:mm').parse(dateStr);
             } catch (e3) {
                return null;
             }
          }
      }
  }

  Widget _buildOrderList(int tabIndex) {
      final list = _getFilteredList(tabIndex);
      
      if (list.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(Icons.inbox_outlined, size: 50, color: Colors.grey),
              SizedBox(height: 10),
              Text("Tidak ada order", style: TextStyle(color: Colors.grey))
          ]));
      }

      final now = DateTime.now();

      return RefreshIndicator(
          onRefresh: _fetchOrders,
          child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                  final order = list[index];
                  final status = (order['status'] ?? 'UNKNOWN').toString().toUpperCase(); 
                  final isDelivery = (order['order_type'] == 'DELIVERY');
                  final schedTime = order['delivery_scheduled_at'];

                  // LOGIC DISPLAY JADWAL (MOVED HERE)
                  String? displayTimeStr = schedTime;
                  // Jika "Sekarang" atau null/kosong, kita cari waktu yang lebih spesifik
                  if (displayTimeStr == null || displayTimeStr == '-' || displayTimeStr.toString().toLowerCase() == 'sekarang') {
                      displayTimeStr = order['ready_time'] ?? order['created_at'];
                  }
                  String formattedSchedule = _formatDate(displayTimeStr);
                  
                  String labelText = isDelivery ? "Jadwal" : "Waktu"; // "Waktu" is neutral for pickup/ready
                  
                  Color cardColor;
                  Color badgeColor;
                  Color badgeTextColor;
                  
                  switch (status) {
                      case 'READY':
                      case 'READY_FOR_PICKUP':
                         cardColor = Colors.white;
                         badgeColor = Colors.blue.shade50;
                         badgeTextColor = Colors.blue.shade800;
                         break;
                      case 'ON_DELIVERY':
                         cardColor = Colors.orange.shade50;
                         badgeColor = Colors.white;
                         badgeTextColor = Colors.orange.shade900;
                         break;
                      case 'COMPLETE':
                      case 'DONE':
                      case 'DELIVERED':
                         cardColor = Colors.green.shade50;
                         badgeColor = Colors.white;
                         badgeTextColor = Colors.green.shade800;
                         break;
                      case 'CANCELLED':
                         cardColor = Colors.red.shade50;
                         badgeColor = Colors.white;
                         badgeTextColor = Colors.red.shade800;
                         break;
                      default:
                         cardColor = Colors.grey.shade50;
                         badgeColor = Colors.grey.shade200;
                         badgeTextColor = Colors.black87;
                  }

                  // --- CALCULATE TIMER ---
                  // Logic dipindahkan ke OrderTimerWidget sepenuhnya
                  // DateTime? startTime; ... logic removed ...


                  return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                          border: Border.all(color: badgeColor, width: 1)
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                               await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderNumber: order['order_number'])));
                               _fetchOrders();
                          },
                          child: Padding(
                             padding: const EdgeInsets.all(16), 
                             child: Column(children: [
                                 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                     Row(children: [
                                         Icon(isDelivery ? Icons.motorcycle : Icons.store, size: 16, color: Colors.grey),
                                         const SizedBox(width: 8),
                                         Text("#${order['order_number']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                     ]),
                                     Row(
                                       children: [
                                          // --- TIMER DISPLAY ---
                                          if (status != 'COMPLETE' && status != 'CANCELLED' && status != 'DONE') 
                                              OrderTimerWidget(order: order),
                                          
                                          Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
                                              child: Text(status, style: TextStyle(color: badgeTextColor, fontSize: 10, fontWeight: FontWeight.bold))
                                          ),
                                       ],
                                     )
                                   ],
                                 ),
                                 const Divider(height: 24),
                                 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                     Expanded(
                                       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                           Text(order['customer_name'] ?? 'Pelanggan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                           const SizedBox(height: 4),
                                           // TAMPILKAN JADWAL ATAU TIPE
                                           // TAMPILKAN JADWAL ATAU TIPE
                                           if (formattedSchedule != '-') ...[
                                              Row(children: [
                                                Icon(Icons.access_time, size: 12, color: isDelivery ? Colors.red : Colors.blue.shade700),
                                                const SizedBox(width: 4),
                                                Text("$labelText: $formattedSchedule", style: TextStyle(color: isDelivery ? Colors.red : Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                                              ])
                                           ] else ...[
                                              Text(isDelivery ? "Belum Jadwal" : "Ambil Sendiri", style: TextStyle(color: Colors.grey.shade700, fontSize: 12))
                                           ]
                                       ]),
                                     ),
                                     Text("Rp ${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(order['total_amount'])}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87))
                                 ])
                             ]),
                          )
                        ),
                      ),
                  );
              },
          ),
      );
  }
}

