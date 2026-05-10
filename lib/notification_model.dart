import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'notification_service.dart';

class NotificationModel extends ChangeNotifier {
  Timer? _timer;
  int _lastOrderId = 0;
  int _unreadCount = 0;
  List<int> _notifiedOrderIds = [];

  int get unreadCount => _unreadCount;

  void startPolling() {
    print("=== [DEBUG] NotificationModel: Start Polling Called ==="); 
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
       if (!ApiService.isAuthenticated()) return; 

       try {
         final api = ApiService();
         
         // 1. Cek Role User saat ini
         final profile = await api.getProfile();
         if (profile == null) return;
         final String role = (profile['role'] ?? '').toString().toLowerCase();

         // 2. Ambil Data (API yang dipanggil bisa beda tergantung kebutuhan, 
         // tapi getOrderHistory cukup umum jika backend filter usernya benar)
         final response = role == 'kurir' 
             ? await api.getCourierOrders() 
             : await api.getOrderHistory();
         
         List<dynamic> orders = [];

         if (role == 'kurir') {
            // getCourierOrders returns List<dynamic> directly based on ApiService
            if (response is List) {
               orders = response;
            }
         } else {
            // getOrderHistory returns Map<String, dynamic>?
            if (response is Map && response['data'] != null) {
               orders = response['data'];
            }
         }
           
         // 3. Filter berdasarkan Role
         final newOrders = orders.where((o) {
            final status = (o['status'] ?? '').toString().toUpperCase();
            
            if (role == 'kurir') {
              // Kurir hanya peduli yang statusnya READY (Siap Diantar)
              return status == 'READY';
            } else {
              // Kasir/Admin peduli yang statusnya DRAFT/PREPARED (Pesanan Baru Masuk)
              return status == 'DRAFT' || status == 'PREPARED';
            }
         }).toList();
           
         if (newOrders.isNotEmpty) {
           int newCount = 0;
           for (var order in newOrders) {
              int id = order['id'];
              
              if (!_notifiedOrderIds.contains(id)) {
                 _notifiedOrderIds.add(id);
                 newCount++;
                 
                 // Customize Message
                 String title = 'Pesanan Baru #${order['order_number']}';
                 String body = 'Segera proses pesanan ini.';
                 
                 if (role == 'kurir') {
                   title = '🎉 Siap Diantar! #${order['order_number']}';
                   body = 'Pesanan sudah siap. Ambil dan antar ke pelanggan sekarang!';
                 }

                 NotificationService().showNotification(
                    id: id, 
                    title: title, 
                    body: body
                 );
              }
           }

           if (newCount > 0) {
             _unreadCount += newCount;
             notifyListeners();
           }
         }
       } catch (e) {
         print('Polling error: $e');
       }
    });
  }

  void stopPolling() {
    _timer?.cancel();
  }

  void markAsRead() {
    _unreadCount = 0;
    notifyListeners();
  }

  // Clear notified list saat logout
  void clear() {
    _unreadCount = 0;
    _notifiedOrderIds.clear();
    stopPolling();
    notifyListeners();
  }
}
