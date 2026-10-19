import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:depotair_app/api_service.dart';
import 'package:depotair_app/cart_model.dart';
import 'package:depotair_app/login_screen.dart';
import 'package:depotair_app/notification_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartModel Unit Tests', () {
    test('CartModel starts empty and adds items accurately', () {
      final cart = CartModel();
      expect(cart.items, isEmpty);
      expect(cart.totalItems, 0);
      expect(cart.subtotal, 0.0);

      cart.addItem({'id': 1, 'name': 'Galon Isi Ulang', 'price': 6000});
      expect(cart.totalItems, 1);
      expect(cart.subtotal, 6000.0);

      // Adding the same item increments quantity
      cart.addItem({'id': 1, 'name': 'Galon Isi Ulang', 'price': 6000});
      expect(cart.totalItems, 1);
      expect(cart.findItemById(1)?.quantity, 2);
      expect(cart.subtotal, 12000.0);
    });

    test('CartModel updates quantity, removes on zero, and clears cart', () {
      final cart = CartModel();
      cart.addItem({'id': 10, 'name': 'Galon Baru', 'price': 50000});
      cart.addItem({'id': 20, 'name': 'Tutup Galon', 'price': 2000});

      cart.updateQuantity(10, 3);
      expect(cart.subtotal, 152000.0);

      cart.updateQuantity(20, 0);
      expect(cart.findItemById(20), isNull);
      expect(cart.totalItems, 1);

      cart.clearCart();
      expect(cart.items, isEmpty);
      expect(cart.subtotal, 0.0);
    });
  });

  group('NotificationModel & ApiService Auth State Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ApiService.init();
    });

    test('ApiService is unauthenticated when no token is stored', () {
      expect(ApiService.isAuthenticated(), isFalse);
      expect(ApiService.getCachedRole(), isNull);
    });

    test('NotificationModel tracks and resets unread state cleanly', () {
      final model = NotificationModel();
      expect(model.unreadCount, 0);
      model.markAsRead();
      expect(model.unreadCount, 0);
      model.clear();
      expect(model.unreadCount, 0);
    });
  });

  group('LoginScreen Widget Smoke Test', () {
    testWidgets('LoginScreen renders email/password fields and submit button',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await ApiService.init();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CartModel()),
            ChangeNotifierProvider(create: (_) => NotificationModel()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
      expect(find.text('Masuk Akun'), findsOneWidget);
    });
  });
}
