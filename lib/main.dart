import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'api_service.dart';
import 'cart_model.dart'; 
import 'notification_model.dart'; // Import ini 
import 'package:intl/date_symbol_data_local.dart';
import 'offline_service.dart'; // Import OfflineService
// import 'splash_screen.dart'; // Import Splash Screen (Removed)
import 'package:intl/intl.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz; // Import TimeZone Data
import 'package:timezone/timezone.dart' as tz;    // Import TimeZone Core
import 'role_based_router.dart'; // <-- Re-added import
import 'notification_service.dart';
import 'order_timer_manager.dart';



void main() async {
  // Wajib dipanggil sebelum SharedPreferences digunakan di ApiService.init()
  WidgetsFlutterBinding.ensureInitialized();
  print("=== [DEBUG] APP STARTING: main() EXECUTED ==="); // LOGGING

  
  // Inisialisasi data formatting untuk locale Indonesia
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';

  // Inisialisasi TimeZone
  tz.initializeTimeZones();
  // Set lokasi default ke Jakarta (WIB)
  final location = tz.getLocation('Asia/Jakarta');
  tz.setLocalLocation(location);

  await ApiService.init(); 
  try {
    await NotificationService().init(); 
    print("DEBUG: NotificationService initialized SUCCESS");
  } catch (e) {
    print("DEBUG: NotificationService initialized FAILED: $e");
  }
  


  OfflineService().init(); // Moved here from SplashScreen
  OrderTimerManager().start(); // Start monitoring orders

  // Gunakan MultiProvider agar bisa inject banyak provider
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartModel()),
        ChangeNotifierProvider(create: (_) => NotificationModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Depotair POS', // Judul diperbarui
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // PENTING: Home sekarang diarahkan langsung ke RoleBasedRouter.
      home: const RoleBasedRouter(), 
    );
  }
}