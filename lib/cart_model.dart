// cart_model.dart
import 'package:flutter/material.dart';

class CartItem {
  final int id;
  final String name;
  final double price;
  int quantity;

  CartItem({required this.id, required this.name, required this.price, this.quantity = 1});
}

class CartModel with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;
  
  // Hitung subtotal keseluruhan
  double get subtotal => _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  
  // Hitung total item unik
  int get totalItems => _items.length;

  // Cek apakah produk sudah ada di Cart
  CartItem? findItemById(int id) {
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  void addItem(Map<String, dynamic> product) {
    final int productId = product['id'];
    final CartItem? existingItem = findItemById(productId);

    if (existingItem != null) {
      existingItem.quantity++;
    } else {
      _items.add(
        CartItem(
          id: productId,
          name: product['name'],
          price: (product['price'] as num).toDouble(),
          quantity: 1,
        ),
      );
    }
    notifyListeners();
  }
  
  void removeItem(int id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void updateQuantity(int id, int newQuantity) {
    final item = findItemById(id);
    if (item != null && newQuantity > 0) {
      item.quantity = newQuantity;
      notifyListeners();
    } else if (item != null && newQuantity <= 0) {
       removeItem(id);
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}