import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz; // Import Timezone

class OrderTimerManager {
  static final OrderTimerManager _instance = OrderTimerManager._internal();
  factory OrderTimerManager() => _instance;
  OrderTimerManager._internal();

  Timer? _timer;
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();
  
  // Cache triggered notifications to avoid spamming every second
  // Map<OrderId_Status, LastNotificationTime>
  final Map<String, DateTime> _lastAlerted = {};
  
  // Config
  static const int limitMinutes = 15;
  static const Duration checkInterval = Duration(minutes: 1);
  // Recurring alert interval (remind EVERY 1 MINUTE if ignored)
  static const int recurringAlertMinutes = 1; 

  void start() {
    if (_timer != null) return;
    print("Starting OrderTimerManager...");
    _checkOrders(); // Run immediately
    _timer = Timer.periodic(checkInterval, (timer) {
      _checkOrders();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }



// ... existing code ...

  Future<void> _checkOrders() async {
    if (!ApiService.isAuthenticated()) return;

    try {
      final String? role = ApiService.getCachedRole(); // Cek Role
      List<dynamic> orders = [];

      if (role == 'kurir' || role == 'courier') {
         // KHUSUS KURIR: Ambil dari endpoint kurir
         print("DEBUG TIMER: Checking COURIER orders...");
         orders = await _apiService.getCourierOrders();
      } else {
         // KASIR / OWNER: Ambil dari History
         // print("DEBUG TIMER: Checking HISTORY orders...");
         final response = await _apiService.getOrderHistory();
         if (response != null && response['data'] != null) {
            orders = response['data'];
         }
      }

      // GANTI DateTime.now() JADI TimeZone Aware (Jakarta)
      final now = tz.TZDateTime.now(tz.local); 

      for (var order in orders) {
        _processOrder(order, now);
      }
    } catch (e) {
      print("Error checking order timers: $e");
    }
  }

  void _processOrder(Map<String, dynamic> order, tz.TZDateTime now) { // Update type
    final status = (order['status'] as String? ?? '').toUpperCase();
    final orderId = order['id'].toString();
    final orderNumber = order['order_number'] as String;

    tz.TZDateTime? startTime; // Update type

    if (status == 'DRAFT') {
      startTime = _parseDateToWIB(order['created_at']);
    } else if (status == 'READY') {
      startTime = _parseDateToWIB(order['ready_time']);
    } else if (status == 'ON_DELIVERY') {
       startTime = _parseDateToWIB(order['delivery_time']);
    } else {
      return; 
    }

    if (startTime == null) return;

    final diff = now.difference(startTime);
    final minutesElapsed = diff.inMinutes;

    if (minutesElapsed >= limitMinutes) {
        // print("DEBUG ALERT: Order #$orderNumber elapsed $minutesElapsed mins (Now: $now | Start: $startTime)");
        _triggerAlert(orderId, orderNumber, status, minutesElapsed, now);
    }
  }

  void _triggerAlert(String orderId, String orderNumber, String status, int minutesElapsed, tz.TZDateTime now) {
      final key = "${orderId}_$status";
      final lastAlert = _lastAlerted[key]; // Ini DateTime biasa gak masalah, cuma buat interval

      // Interval check logic (tetap sama)
      if (lastAlert == null || now.difference(lastAlert).inMinutes >= recurringAlertMinutes) {
          
          String title = "Perhatian: Order #$orderNumber";
          String body = "";

          if (status == 'DRAFT') {
              body = "Order masih DRAFT selama $minutesElapsed menit! Segera proses.";
          } else if (status == 'READY') {
              body = "Belum diambil dalam $minutesElapsed menit! Segera antar.";
          } else if (status == 'ON_DELIVERY') {
               body = "Pengantaran lama ($minutesElapsed menit)! Segera selesaikan.";
          }

          if (body.isNotEmpty) {
              _notificationService.showNotification(
                  id: int.tryParse(orderId) ?? now.millisecond, 
                  title: title, 
                  body: body
              );
              _lastAlerted[key] = now; // Simpan waktu alert terakhir
              print("Triggered alert for $orderNumber ($status)");
          }
      }
  }

  // Helper baru: Force string ke WIB
  tz.TZDateTime? _parseDateToWIB(String? dateStr) {
    if (dateStr == null || dateStr == '-') return null;
    try {
      DateTime? dt;
      // 1. Coba parse standar ISO
      dt = DateTime.tryParse(dateStr); 
      
      // 2. Jika gagal, coba format manual 'd/m/Y H:i'
      if (dt == null) {
        dt = DateFormat('d/M/y H:i').parse(dateStr); 
      }
      
      // 3. Konversi DateTime (Local HP) ke DateTime (Komponen Waktu) -> Force ke WIB
      // Kita ambil angka jam/menitnya mentah-mentah, lalu kita "cap" sebagai jam WIB.
      // Ini asumsi server kirim string "2023-01-01 13:00" yang ARTINYA 13:00 WIB.
      return tz.TZDateTime(
        tz.local, // Lokasi 'Asia/Jakarta' (dari main.dart)
        dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second
      );

    } catch (e) {
      return null;
    }
  }
}
