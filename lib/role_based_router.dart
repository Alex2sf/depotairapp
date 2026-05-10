import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';
import 'login_screen.dart';
import 'main_screen.dart'; // Kasir
import 'owner_screen.dart'; // Owner/Admin
import 'courier_screen.dart'; // Kurir
import 'notification_service.dart'; 
import 'notification_model.dart';

class RoleBasedRouter extends StatefulWidget {
  const RoleBasedRouter({super.key});

  @override
  State<RoleBasedRouter> createState() => _RoleBasedRouterState();
}

class _RoleBasedRouterState extends State<RoleBasedRouter> {
  Widget _currentScreen = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  void initState() {
    super.initState();
    _initNotifications();
    // Start polling via Provider
    // Start polling via Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
       print("=== [DEBUG] RoleBasedRouter: Trying to access NotificationModel... ===");
       try {
          final notifModel = Provider.of<NotificationModel>(context, listen: false);
          print("=== [DEBUG] RoleBasedRouter: SUCCESS accessing NotificationModel ===");
          notifModel.startPolling();
       } catch (e) {
          print("=== [DEBUG] RoleBasedRouter: FAILED to access NotificationModel! Error: $e ===");
          print("=== [DEBUG] POSSIBLE CAUSE: main() was not re-run. Please RESTART APP (Press q then flutter run) ===");
       }
    });
    _checkAuthAndRedirect();
  }

  void _initNotifications() {
    NotificationService().init();
  }


  Future<void> _checkAuthAndRedirect() async {
    // Delay sedikit agar aman dari masalah setState saat init
    await Future.delayed(Duration.zero);

    if (!mounted) return;

    // 1. Cek Token (Login)
    if (!ApiService.isAuthenticated()) {
      _replaceWith(const LoginScreen());
      return;
    }

    // 2. Cek Profil (Role)
    final profile = await ApiService().getProfile();

    if (!mounted) return;

    String? role;

    if (profile == null) {
      // Profile null BISA karena Token Expired (401) ATAU Network Error
      // Jika Token masih ada (ApiService tidak menghapusnya), berarti itu Network Error
      if (ApiService.isAuthenticated()) {
         print("=== [DEBUG] Network/Server Error but Token Exists. Using Cached Role. ===");
         role = ApiService.getCachedRole();
         
         if (role == null) {
            // Apes, token ada tapi role belum tercache (baru pertama instal?)
            // Terpaksa logout atau tampilkan error retry
             await ApiService.clearToken();
            _replaceWith(const LoginScreen());
            return;
         }
      } else {
         // Token sudah dihapus oleh ApiService (karena 401 Unauthorized)
         _replaceWith(const LoginScreen());
         return;
      }
    } else {
       // Online & Sukses
       role = (profile['role'] as String?)?.toLowerCase();
    }
    
    // --- LOGIKA ROUTING BERDASARKAN ROLE (UPDATED) ---
    
    if (role != null) {
        role = role.toLowerCase();
    }

    // Owner DAN Admin diarahkan ke OwnerScreen (Menu Utama Owner)
    if (role == 'owner' || role == 'admin') {
      _replaceWith(OwnerScreen());
    } 
    // Kasir diarahkan ke MainScreen (POS)
    else if (role == 'kasir') {
      _replaceWith(MainScreen());
    } 
    // Kurir diarahkan ke Screen Kurir
    else if (role == 'kurir') {
      _replaceWith(CourierScreen());
    } 
    // Role tidak dikenali -> Logout
    else {
      await ApiService.clearToken();
      _replaceWith(const LoginScreen());
    }
  }

  void _replaceWith(Widget screen) {
    if (!mounted) return;
    setState(() {
      _currentScreen = screen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _currentScreen;
  }
}