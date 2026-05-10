import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';

class OfflineService {
  static const String _pendingOrdersKey = 'pending_orders';
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Singleton pattern
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  /// Initialize listener for connectivity changes
  void init() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Check if any result is NOT none
      bool isConnected = results.any((result) => result != ConnectivityResult.none);
      if (isConnected) {
        print("=== [OFFLINE SERVICE] Online detected. Attempting sync... ===");
        syncPendingOrders();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Check if device is currently online
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  /// Save an order to local storage (SharedPreferences)
  Future<void> savePendingOrder(Map<String, dynamic> orderData) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingList = prefs.getStringList(_pendingOrdersKey) ?? [];
    
    // Add timestamp for debug/info
    orderData['saved_at_local'] = DateTime.now().toIso8601String();
    
    pendingList.add(json.encode(orderData));
    await prefs.setStringList(_pendingOrdersKey, pendingList);
    print("=== [OFFLINE SERVICE] Order saved locally. Total pending: ${pendingList.length} ===");
  }

  /// Retrieve all pending orders
  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingList = prefs.getStringList(_pendingOrdersKey) ?? [];
    return pendingList.map((e) => json.decode(e) as Map<String, dynamic>).toList();
  }

  /// Clear all pending orders (dangerous, use carefully)
  Future<void> clearPendingOrders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingOrdersKey);
  }

  /// Attempt to sync all pending orders to server
  Future<void> syncPendingOrders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingList = prefs.getStringList(_pendingOrdersKey) ?? [];

    if (pendingList.isEmpty) return;

    print("=== [OFFLINE SERVICE] Syncing ${pendingList.length} orders... ===");
    
    List<String> remainingList = [];
    int successCount = 0;

    for (String orderJson in pendingList) {
      try {
        final orderData = json.decode(orderJson) as Map<String, dynamic>;
        
        // Remove local metadata before sending if needed, or keep it.
        // ApiService.checkoutOrder expects raw order data.
        
        // We bypass the 'isOnline' check inside ApiService (if we add one there) 
        // by calling a direct private method or just assuming ApiService will try http.
        
        final result = await ApiService().checkoutOrder(orderData, isSyncing: true);
        
        if (result != null && result['success'] == true) {
          successCount++;
          print("=== [OFFLINE SERVICE] Sync Success for order customer: ${orderData['customer_id']} ===");
        } else {
          // Keep in list if failed (server error, or still unstable)
          remainingList.add(orderJson);
          print("=== [OFFLINE SERVICE] Sync Failed: ${result?['message']} ===");
        }
      } catch (e) {
        remainingList.add(orderJson);
        print("=== [OFFLINE SERVICE] Sync Error: $e ===");
      }
    }

    // Update local storage with remaining
    await prefs.setStringList(_pendingOrdersKey, remainingList);
    
    if (successCount > 0) {
      // Optional: Show local notification or toast? 
      // Since this runs in background mostly, print is safe.
      print("=== [OFFLINE SERVICE] Sync Completed. $successCount uploaded, ${remainingList.length} remaining. ===");
    }
  }
}
