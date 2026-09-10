import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'notification_model.dart';
import 'courier_detail_screen.dart';
import 'role_based_router.dart';
import 'widgets/custom_dialogs.dart';
import 'widgets/order_timer_widget.dart';
import 'widgets/courier_reminder_dialog.dart';

class CourierScreen extends StatefulWidget {
  const CourierScreen({super.key});

  @override
  State<CourierScreen> createState() => _CourierScreenState();
}

class _CourierScreenState extends State<CourierScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _selectedStatus; // null means ALL
  String? _filterDate;     // null means ALL, 'today' means TODAY

  // Reminder pop-up settings
  static const int _overdueThresholdMinutes = 60; // 1 Jam batas normal
  static const int _snoozeMinutes = 15; // Tunda 15 menit jika pilih "Masih di Jalan"
  final Map<String, DateTime> _snoozedOrders = {}; // orderNumber -> snoozeUntil
  bool _isCheckingReminder = false;

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'id';
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    final orders = await _apiService.getCourierOrders(
        status: _selectedStatus,
        date: _filterDate
    );
    if (mounted) {
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
      // Periksa apakah ada order ON_DELIVERY yang melebihi batas waktu
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkOverdueDeliveries();
      });
    }
  }

  DateTime? _parseOrderTimestamp(String? timestampStr) {
    if (timestampStr == null || timestampStr.isEmpty || timestampStr == '-') return null;
    try {
      return DateTime.parse(timestampStr).toLocal();
    } catch (_) {
      try {
        return DateFormat('dd/MM/yyyy HH:mm').parse(timestampStr);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _checkOverdueDeliveries() async {
    if (!mounted || _isCheckingReminder || _orders.isEmpty) return;

    final now = DateTime.now();
    Map<String, dynamic>? mostOverdueOrder;
    int maxMinutesElapsed = 0;

    for (var rawOrder in _orders) {
      if (rawOrder is! Map<String, dynamic>) continue;
      final status = (rawOrder['status'] ?? '').toString().toUpperCase();
      if (status != 'ON_DELIVERY') continue;

      final orderNumber = rawOrder['order_number']?.toString();
      if (orderNumber == null || orderNumber.isEmpty) continue;

      // Cek apakah order ini sedang di-snooze
      final snoozeUntil = _snoozedOrders[orderNumber];
      if (snoozeUntil != null && now.isBefore(snoozeUntil)) {
        continue; // Masih dalam masa tunda
      }

      // Hitung selisih waktu dari delivery_time (atau ready_time / created_at)
      final deliveryTime = _parseOrderTimestamp(rawOrder['delivery_time']?.toString())
          ?? _parseOrderTimestamp(rawOrder['ready_time']?.toString())
          ?? _parseOrderTimestamp(rawOrder['created_at']?.toString());

      if (deliveryTime == null) continue;

      final elapsedMinutes = now.difference(deliveryTime).inMinutes;
      if (elapsedMinutes >= _overdueThresholdMinutes && elapsedMinutes > maxMinutesElapsed) {
        maxMinutesElapsed = elapsedMinutes;
        mostOverdueOrder = rawOrder;
      }
    }

    if (mostOverdueOrder != null && mounted) {
      _isCheckingReminder = true;
      final orderNumber = mostOverdueOrder['order_number']?.toString() ?? '';

      final action = await showCourierReminderDialog(
        context: context,
        order: mostOverdueOrder,
        minutesElapsed: maxMinutesElapsed,
      );

      _isCheckingReminder = false;

      if (!mounted) return;

      if (action == CourierReminderAction.alreadyFinished) {
        // Arahkan kurir langsung ke detail order untuk foto bukti & selesaikan
        _navigateToDetail(orderNumber);
      } else if (action == CourierReminderAction.stillOnTheWay) {
        // Tunda reminder untuk order ini selama 15 menit
        _snoozedOrders[orderNumber] = DateTime.now().add(const Duration(minutes: _snoozeMinutes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Pengingat untuk #$orderNumber ditunda $_snoozeMinutes menit."),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showLogoutDialog(context);

    if (!confirmed || !mounted) return;
    await _apiService.logout();
    if (mounted) {
       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (_) => const RoleBasedRouter()),
         (route) => false,
       );
    }
  }

  void _navigateToDetail(String orderNumber) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CourierDetailScreen(orderNumber: orderNumber)),
    );
    if (result == true) _fetchOrders();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr == 'Sekarang') return 'Sekarang';
    try {
      final date = DateFormat('dd/MM/yyyy HH:mm').parse(dateStr);
      // Format explisit: Sab, 20 Des 14:00
      return DateFormat('EEE, dd MMM HH:mm', 'id').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    int draftCount = _orders.where((o) => o['status'] == 'DRAFT').length;
    int readyCount = _orders.where((o) => o['status'] == 'READY').length;
    int deliveryCount = _orders.where((o) => o['status'] == 'ON_DELIVERY').length;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: BoxDecoration(
               gradient: LinearGradient(colors: [Colors.orange.shade900, Colors.orange.shade600]),
               boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Text("Halo, Kurir!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          Text("Siap antar kebahagiaan?", style: TextStyle(color: Colors.white70)),
                       ],
                    ),
                    Row(
                       children: [
                          Consumer<NotificationModel>(
                            builder: (context, notif, child) => Stack(
                              children: [
                                IconButton(icon: const Icon(Icons.notifications, color: Colors.white), onPressed: () { notif.markAsRead(); _fetchOrders(); }),
                                if (notif.unreadCount > 0)
                                  Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('${notif.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10))))
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _handleLogout),
                       ],
                    )
                  ],
                ),
                const SizedBox(height: 20),
                // STATS (NOW CLICKABLE FILTERS)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatCard("Draft", draftCount, Colors.grey.shade700, 'DRAFT', width: 100),
                      const SizedBox(width: 8),
                      _buildStatCard("Siap Diantar", readyCount, Colors.blue, 'READY', width: 130),
                      const SizedBox(width: 8),
                      _buildStatCard("Sedang Jalan", deliveryCount, Colors.orange, 'ON_DELIVERY', width: 140),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // --- FILTER PERMINTAAN USER ---
                Row(
                   children: [
                      // FILTER TANGGAL (HARI INI / SEMUA)
                      Expanded(
                          child: Container(
                             height: 36,
                             decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(18)),
                             child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                   _buildFilterDateOption('Semua', null),
                                   Container(width: 1, height: 20, color: Colors.white30),
                                   _buildFilterDateOption('Hari Ini', 'today'),
                                ],
                             ),
                          ),
                      ),
                      const SizedBox(width: 12),
                      // FILTER TOMBOL RESET (Show All Status)
                       if (_selectedStatus != null)
                          ActionChip(
                              label: const Text('Reset Status'),
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(color: Colors.orange.shade900),
                              onPressed: () {
                                  setState(() => _selectedStatus = null);
                                  _fetchOrders();
                              },
                          ),
                   ],
                ),
              ],
            ),
          ),

          // LIST
          Expanded(
             child: RefreshIndicator(
                onRefresh: _fetchOrders,
                child: _isLoading 
                   ? const Center(child: CircularProgressIndicator())
                   : _orders.isEmpty 
                      ? ListView(children: [
                          const SizedBox(height: 100), 
                          Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 60, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(_selectedStatus != null ? "Tidak ada di status ini." : "Tidak ada tugas pengantaran.", style: const TextStyle(color: Colors.grey)),
                                  if (_filterDate == 'today') const Text("Untuk Hari Ini", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              )
                          )
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
                        ),
             ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color, String statusKey, {double? width}) {
     final bool isActive = _selectedStatus == statusKey;
     return GestureDetector(
       onTap: () {
           setState(() => _selectedStatus = isActive ? null : statusKey); // Toggle
           _fetchOrders();
       },
       child: Container(
         width: width,
         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
         decoration: BoxDecoration(
             color: isActive ? Colors.white : Colors.white.withOpacity(0.2), 
             borderRadius: BorderRadius.circular(12),
             border: isActive ? Border.all(color: color, width: 2) : null,
         ),
         child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isActive ? color.withOpacity(0.1) : Colors.white, shape: BoxShape.circle), child: Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color))),
               const SizedBox(width: 8),
               Expanded(child: Text(title, style: TextStyle(color: isActive ? color : Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis))
            ],
         ),
       ),
     );
  }

  Widget _buildFilterDateOption(String label, String? value) {
      final bool isSelected = _filterDate == value;
      return GestureDetector(
          onTap: () {
              if (_filterDate == value) return;
              setState(() => _filterDate = value);
              _fetchOrders();
          },
          child: Container(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(16)
             ),
             child: Text(label, style: TextStyle(
                 color: isSelected ? Colors.orange.shade900 : Colors.white70, 
                 fontWeight: FontWeight.bold,
                 fontSize: 12
             )),
          ),
      );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
     String status = order['status'];
     bool isReady = status == 'READY';
     bool isDraft = status == 'DRAFT';

     String statusText = isReady ? "SIAP DIANTAR" 
                        : isDraft ? "MEMASAK" 
                        : "SEDANG JALAN";
     
     Color cardColor = isReady ? Colors.white : (isDraft ? Colors.grey.shade50 : Colors.orange.shade50);
     Color badgeColor = isReady ? Colors.blue.shade50 : (isDraft ? Colors.grey.shade200 : Colors.white);
     Color badgeTextColor = isReady ? Colors.blue.shade800 : (isDraft ? Colors.grey.shade800 : Colors.orange.shade900);
     Color borderColor = isReady ? Colors.blue.shade100 : (isDraft ? Colors.grey.shade300 : Colors.orange.shade200);

     if (!isReady && !isDraft && !status.contains('ON_DELIVERY')) {
         cardColor = Colors.grey.shade50;
     }

     return Container(
       margin: const EdgeInsets.only(bottom: 16),
       decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
          border: Border.all(color: borderColor, width: 1),
       ),
       child: Material(
         color: Colors.transparent,
         child: InkWell(
           onTap: () => _navigateToDetail(order['order_number']),
           borderRadius: BorderRadius.circular(16),
           child: Padding(
             padding: const EdgeInsets.all(16),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Flexible( // Allow left side (Timer + Badge) to take needed space
                           flex: 3,
                           child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible( // Allow badge text to shrink if really tight
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
                                    child: Text(
                                      statusText, 
                                      style: TextStyle(color: badgeTextColor, fontWeight: FontWeight.bold, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ],
                           ),
                        ),
                        const SizedBox(width: 8),
                        Flexible( // Allow order number to shrink/ellipsis
                           flex: 2,
                           child: Text(
                             "#${order['order_number']}", 
                             style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                             overflow: TextOverflow.ellipsis,
                             maxLines: 1,
                           )
                        )
                     ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       const Icon(Icons.person, size: 20, color: Colors.grey),
                       const SizedBox(width: 8),
                       Expanded(child: Text(order['customer'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       const Icon(Icons.location_on, size: 20, color: Colors.red),
                       const SizedBox(width: 8),
                       Expanded(child: Text(order['alamat'] ?? '-', style: const TextStyle(color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Row(
                           children: [
                              OrderTimerWidget(order: order),
                              if (order['delivery_scheduled_at'] != null && order['delivery_scheduled_at'] != 'Sekarang')
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                   decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.indigo.shade100)),
                                   child: Row(
                                     children: [
                                       const Icon(Icons.access_time_filled, size: 14, color: Colors.indigo),
                                       const SizedBox(width: 6),
                                       Text("Jadwal: ${_formatDate(order['delivery_scheduled_at'])}", style: TextStyle(fontSize: 13, color: Colors.indigo.shade900, fontWeight: FontWeight.bold)),
                                     ],
                                   ),
                                 ),
                           ],
                        ),
                        
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
                     ],
                  )
               ],
             ),
           ),
         ),
       ),
     );
  }
}