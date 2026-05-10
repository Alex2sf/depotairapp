import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // This will be executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: true,
      isForegroundMode: true,

      notificationChannelId: 'depotair_background_channel',
      initialNotificationTitle: 'Depotair Service',
      initialNotificationContent: 'Memantau pesanan baru...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

// iOS Background handler (required but simplified for now)
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  // Return true to indicate success
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  // Initialize dependencies in this isolate
  await ApiService.init(); 
  await NotificationService().init();

  // Keep track of notified orders to prevent spam
  List<int> notifiedOrderIds = [];

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
    

  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Start the polling timer
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (await service is AndroidServiceInstance) {
      if (await (service as AndroidServiceInstance).isForegroundService()) {
        // Optional: Update notification content to show last check time
        // service.setForegroundNotificationInfo(
        //   title: "Depotair Service",
        //   content: "Terakhir dicek: ${DateTime.now()}",
        // );
      }
    }
    
    // LOGIC POLLING (Copy from NotificationModel but using standalone instances)
    try {
       // Re-init prefs inside loop if needed? No, ApiService.init() is once per isolate.
       // But wait, if user Logs In in Main Isolate, the Prefs in Background Isolate might be stale 
       // until re-read. ApiService uses static variables which are NOT shared.
       // So we MUST reload SharedPreferences to get the latest Token.
       await ApiService.init(); 

       if (!ApiService.isAuthenticated()) {
          print("[Background] Not authenticated. Waiting...");
          return;
       }

       final profile = await ApiService().getProfile();
       if (profile == null) return;

       final String role = (profile['role'] ?? '').toString().toLowerCase();
       
       final api = ApiService();
       final response = role == 'kurir' 
             ? await api.getCourierOrders() 
             : await api.getOrderHistory();
         
       List<dynamic> orders = [];

       if (role == 'kurir') {
          if (response is List) {
             orders = response;
          }
       } else {
          // getOrderHistory returns Map
          if (response is Map && response['data'] != null) {
             orders = response['data'];
          }
       }
         
       // Filter Logic
       final newOrders = orders.where((o) {
          final status = (o['status'] ?? '').toString().toUpperCase();
          if (role == 'kurir') {
            return status == 'READY';
          } else {
            return status == 'DRAFT' || status == 'PREPARED';
          }
       }).toList();
         
       if (newOrders.isNotEmpty) {
         for (var order in newOrders) {
            int id = order['id'];
            
            // Periksa apakah ID ini baru bagi isolate ini
            if (!notifiedOrderIds.contains(id)) {
               notifiedOrderIds.add(id);
               
               // Customize Message
               String title = 'Pesanan Baru #${order['order_number']}';
               String body = 'Segera proses pesanan ini.';
               
               if (role == 'kurir') {
                 title = '🎉 Siap Diantar! #${order['order_number']}';
                 body = 'Pesanan sudah siap. Ambil dan antar ke pelanggan sekarang!';
               }

               // Show Notification using local notifications logic
               print("[Background] Showing Notification for Order #$id");
               NotificationService().showNotification(
                  id: id, 
                  title: title, 
                  body: body
               );
            }
         }
       } else {
         print("[Background] No new orders found.");
       }

    } catch (e) {
      print("[Background] Error: $e");
    }
  });
}
