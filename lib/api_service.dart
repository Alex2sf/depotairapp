import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'offline_service.dart';

// 2. GANTI KE IP INI JIKA PAKAI HP ASLI
const String _baseUrl = 'https://hydroexpert.my.id/api'; // PRODUCTION
// 2. GANTI KE IP INI JIKA PAKAI HP ASLI / EMULATOR
// const String _baseUrl = 'http://192.168.1.10/depot/api'; // LOCAL LAN
// const String _baseUrl = 'http://10.0.2.2:8000/api'; // KHUSUS EMULATOR + ARTISAN SERVE


// GUNAKAN SALAH SATU:

class ApiService {
  static String? _token;
  static String? _role;
  static const String _tokenKey = 'authToken';
  static const String _roleKey = 'authRole';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _role = prefs.getString(_roleKey);
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _token = token;
  }
  
  static Future<void> _saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
    _role = role;
  }

  static Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    _token = null;
    _role = null;
  }

  static Future<void> clearToken() async {
    await _clearToken();
  }

  static bool isAuthenticated() => _token != null;
  
  static String? getCachedRole() => _role;

  String _formatErrorMessage(Map<String, dynamic> errors) {
    if (errors.containsKey('image')) {
      final List<dynamic> msgs = errors['image'];
      if (msgs.isNotEmpty) {
        final String msg = msgs[0].toString();
        if (msg.contains('greater than 5120')) return 'Foto maksimal 5 MB saja ya!';
        if (msg.contains('type') || msg.contains('must be a file of type')) return 'Foto harus JPG atau PNG!';
        if (msg.contains('image')) return 'File harus berupa gambar!';
        if (msg.contains('required')) return 'Foto bukti pengantaran wajib diupload.';
      }
    }
    if (errors.isNotEmpty) {
      final firstKey = errors.keys.first;
      final firstVal = errors[firstKey];
      if (firstVal is List && firstVal.isNotEmpty) {
        return firstVal[0].toString();
      }
    }
    return 'Gagal upload bukti (Validasi gagal)';
  }

  // --- ENDPOINT LOGIN ---
  Future<Map<String, dynamic>> login(String email, String password, String deviceName) async {
    final url = Uri.parse('$_baseUrl/login');
    print('DEBUG LOGIN TRYING: $url'); 

    // --- DIAGNOSTIC: CEK KONEKSI TCP ---
    try {
        print('DEBUG: TRYING TCP CONNECT TO 192.168.1.10:8000...');
        final socket = await Socket.connect('192.168.1.10', 8000, timeout: const Duration(seconds: 5));
        print('DEBUG: TCP CONNECT SUCCESS! (Jalur aman)');
        socket.destroy();
    } catch (e) {
        print('DEBUG: TCP CONNECT FAILED! (Masalah Jaringan/Firewall): $e');
    }
    // -----------------------------------

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'device_name': deviceName,
        }),
      ).timeout(const Duration(seconds: 60)); 
      
      print('DEBUG LOGIN RESPONSE: ${response.statusCode} | ${response.body}');
      
      // Check if response is HTML (HTML usually starts with <)
      if (response.body.trim().startsWith('<')) {
         return {
            'success': false, 
            'message': 'Gagal: Server merespon dengan HTML (bukan JSON). URL mungkin salah atau server error. (Code: ${response.statusCode})'
         };
      }

      final Map<String, dynamic> data = json.decode(response.body);
      
      if (response.statusCode == 200 && data.containsKey('token')) {
        await _saveToken(data['token']);
        
        if (data.containsKey('role')) {
             await _saveRole(data['role']);
        } else if (data.containsKey('user') && data['user']['role'] != null) {
             await _saveRole(data['user']['role']);
        }
        
        return {'success': true};
      } else {
        return {
            'success': false, 
            'message': 'Gagal: ${response.statusCode}. \nRespons: ${response.body}'
        };
      }
    } catch (e) {
      return {
          'success': false, 
          'message': 'Error: $e'
      };
    }
  }

  // --- ENDPOINT LOGOUT ---
  Future<void> logout() async {
    final url = Uri.parse('$_baseUrl/logout');
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );
      await _clearToken();
    } catch (e) {
      // Force clear locally even if network fails
      await _clearToken();
    }
  }

  // --- ENDPOINT GET PROFILE (CEK ROLE) ---
  Future<Map<String, dynamic>?> getProfile() async {
    if (_token == null) return null;
    final url = Uri.parse('$_baseUrl/me');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          // SAVE ROLE
          if (data['user']['role'] != null) {
              await _saveRole(data['user']['role']);
          }
          return data['user']; 
        }
      } else if (response.statusCode == 401) {
          // UNAUTHORIZED -> Token Expired/Invalid -> Force Logout
          await _clearToken();
          return null;
      }
      // Other errors (500, etc) -> Do NOT clear token. Return null.
      return null;
    } catch (e) {
      // Network Error -> Do NOT clear token. Return null.
      return null;
    }
  }

  // --- ENDPOINT GET PRODUCTS ---
  Future<Map<String, dynamic>?> getProducts() async {
    if (_token == null) return null;
    final url = Uri.parse('$_baseUrl/products');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          // Mengembalikan Map UTUH (termasuk 'data' & 'filter_options')
          return data; 
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- ENDPOINT GET OPNAME LIST ---
  Future<Map<String, dynamic>?> getOpnameList() async {
    if (_token == null) return null;
    final url = Uri.parse('$_baseUrl/inventory/opname-list');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          // Mengembalikan Map UTUH (termasuk data, ringkasan, dll)
          return data; 
        }
      } 
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- ENDPOINT POST OPNAME ---
  Future<bool> postOpname(List<Map<String, dynamic>> opnameData, String? notes) async {
    if (_token == null) return false;
    
    final url = Uri.parse('$_baseUrl/inventory/opname');
    
    final Map<String, dynamic> payload = {
      'notes': notes,
      'opname': opnameData,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json', 
        },
        body: json.encode(payload),
      );

      final Map<String, dynamic> data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      } else {
        // Handle validation/server errors
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // --- ENDPOINT POST OPNAME SATU ITEM ---
  Future<bool> postSingleOpname(int productId, int realQuantity, String? notes) async {
    if (_token == null) return false;
    final url = Uri.parse('$_baseUrl/inventory/opname');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'notes': notes ?? 'Penyesuaian real quantity mendadak',
          'opname': [ 
            {
              'product_id': productId,
              'real_quantity': realQuantity,
            }
          ],
        }),
      );
      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // --- ENDPOINT SEARCH/CREATE CUSTOMER ---
  Future<Map<String, dynamic>?> searchOrCreateCustomer({
    required String query, 
    String? name,
    String? phoneNumber,
    String? address,
    bool isNew = false,
  }) async {
    if (_token == null) return null;

    final url = Uri.parse('$_baseUrl/customers/search-or-create');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json', // Force JSON response
        },
        body: json.encode({
          'query': query, 
          'name': name,
          'phone_number': phoneNumber, 
          'address': address ?? '',
          'is_new': isNew,
        }),
      );

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return data; // Return full response including 'customer', 'message', 'is_existing'
        }
      } else if (response.statusCode == 422) {
          return data; // Return validation errors
      }
      return null;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // --- ENDPOINT CHECKOUT ORDER ---
  Future<Map<String, dynamic>?> checkoutOrder(Map<String, dynamic> orderData, {bool isSyncing = false}) async {
    // Cek koneksi internet via OfflineService
    // Jika tidak sedang syncing (transaksi baru) dan OfflineService bilang offline
    if (!isSyncing && !(await OfflineService().isOnline())) {
       await OfflineService().savePendingOrder(orderData);
       return {
         'success': true, 
         'is_offline': true, 
         'message': 'Koneksi terputus. Order disimpan & akan dikirim saat online.'
       };
    }

    if (_token == null) return null;
    final url = Uri.parse('$_baseUrl/orders/checkout');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json', 
        },
        body: json.encode(orderData),
      );
      
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Respon server kosong (Status: ${response.statusCode})'};
      }

      final Map<String, dynamic> data = json.decode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          return data; 
        }
      }
      return data; 
      
    } catch (e) {
      return null; 
    }
  }

  // --- ENDPOINT GET /orders/history ---
  Future<Map<String, dynamic>?> getOrderHistory({
    String? startDate,
    String? endDate,
    String? search,
    int page = 1,
  }) async {
    if (_token == null) return null;

    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
    };

    if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final url = Uri.parse('$_baseUrl/orders/history').replace(queryParameters: queryParams);

    try {
      print('DEBUG: Fetching Orders from $url');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_token'},
      );
      
      print('DEBUG ORDERS RESPONSE: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          return null;
        }
      } else if (response.statusCode == 401) {
         print('DEBUG: Token Expired/Invalid (401). Clearing session.');
         await _clearToken();
         return null;
      } else {
        print('DEBUG: Error Fetching Orders: ${response.body}');
        return null;
      }
    } catch (e) {
      print('DEBUG: Exception Fetching Orders: $e');
      return null;
    }
  }

  // --- ENDPOINT GET /orders/{order_number} ---
  Future<Map<String, dynamic>?> getOrderDetail(String orderNumber) async {
    if (_token == null) return null;
    final url = Uri.parse('$_baseUrl/orders/$orderNumber');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['order'];
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
  
  // --- ENDPOINT COMPLETE ORDER MANUAL ---
  Future<bool> completeOrderManual(String orderNumber) async {
    if (_token == null) return false;
    final url = Uri.parse('$_baseUrl/orders/$orderNumber/complete');
    try {
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $_token'},
      );

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // --- ENDPOINT CANCEL / VOID ORDER ---
  Future<Map<String, dynamic>> cancelOrder(String orderNumber, {String? reason}) async {
    if (_token == null) return {'success': false, 'message': 'Sesi login tidak ditemukan'};
    final url = Uri.parse('$_baseUrl/orders/$orderNumber/cancel');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'reason': reason ?? 'Dibatalkan oleh kasir',
        }),
      );

      final Map<String, dynamic> data = json.decode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Gagal membatalkan pesanan: $e'};
    }
  }

  // --- ENDPOINT MARK ORDER AS READY ---
  Future<Map<String, dynamic>> markOrderAsReady(String orderNumber) async {
    if (_token == null) return {'success': false, 'message': 'Token tidak ada'};
    final url = Uri.parse('$_baseUrl/orders/$orderNumber/ready');
    try {
      final response = await http.post(
        url,
        headers: {
            'Authorization': 'Bearer $_token',
            'Accept': 'application/json', // Force JSON error response
        },
      ).timeout(const Duration(seconds: 30));

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
          return {'success': true, 'message': data['message']};
      } else {
          return {'success': false, 'message': data['message'] ?? 'Gagal mengubah status.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ==========================================================
  // --- ENDPOINT KURIR ---
  // ==========================================================

  Future<List<dynamic>> getCourierOrders({String? status, String? date}) async {
    if (_token == null) return [];
    
    String queryString = '';
    List<String> params = [];
    if (status != null && status.isNotEmpty) params.add('status=$status');
    if (date != null && date.isNotEmpty) params.add('date=$date');
    if (params.isNotEmpty) queryString = '?${params.join('&')}';

    final url = Uri.parse('$_baseUrl/courier/orders$queryString');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCourierOrderDetail(String orderNumber) async {
    if (_token == null) return null;
    final url = Uri.parse('$_baseUrl/courier/orders/$orderNumber');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['order'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> pickupOrder(String orderNumber) async {
    if (_token == null) return false;
    final url = Uri.parse('$_baseUrl/courier/orders/$orderNumber/pickup');
    try {
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $_token'},
      );
      final Map<String, dynamic> data = json.decode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> completeOrder(String orderNumber, {required String notes, required String imagePath}) async {
    if (_token == null) return {'success': false, 'message': 'Token hilang.'};
    final url = Uri.parse('$_baseUrl/courier/orders/$orderNumber/complete');
    
    try {
      var request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $_token'
        ..headers['Accept'] = 'application/json'
        ..fields['notes'] = notes;
      
      if (imagePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      }

      var streamedResponse = await request.send();
      
      final responseBody = await streamedResponse.stream.bytesToString();
      
      Map<String, dynamic> data;
      try {
        data = json.decode(responseBody);
      } catch (_) {
        return {
          'success': false,
          'message': 'Gagal (${streamedResponse.statusCode}): Respon server bukan format JSON.',
        };
      }

      if (streamedResponse.statusCode == 200 && data['success'] == true) {
        // Backend sekarang mengirim full URL di 'image_url'
        final fullImageUrl = data['image_url']; 
        
        return {
            'success': true, 
            'message': data['message'] ?? 'Pesanan selesai diantar!', 
            'image_url': fullImageUrl
        };
      } 
      
      if (data['errors'] != null) {
        final Map<String, dynamic> errors = data['errors'];
        final String userMessage = _formatErrorMessage(errors);
        return {'success': false, 'message': userMessage};
      }
      
      if (streamedResponse.statusCode == 400 && data['message'] != null) {
        return {'success': false, 'message': data['message']};
      }

      return {'success': false, 'message': data['message'] ?? 'Gagal menyelesaikan order.'};

    } catch (e) {
      return {'success': false, 'message': 'Kesalahan pengiriman: $e'};
    }
  }

  // ==========================================================
  // --- ENDPOINT CASH MANAGEMENT ---
  // ==========================================================
  
  // --- ENDPOINT BARU: GET USERS UNTUK DEPOSIT ATAS NAMA ---
  Future<List<Map<String, dynamic>>> getDepositableUsers() async {
    if (_token == null) return [];
    
    // MENGUBAH ENDPOINT SESUAI DENGAN YANG ANDA BUAT DI LARAVEL: /api/kasir/list
    final url = Uri.parse('$_baseUrl/kasir/list'); 
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        // MENGAMBIL DATA DARI KEY 'data' SESUAI RESPONSE LARAVEL ANDA
        return (data['data'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  // --------------------------------------------------------

  Future<Map<String, dynamic>> postCashTransaction({
    required String type, 
    required int amount,
    required String description,
  }) async {
    if (_token == null) return {'success': false, 'message': 'Token hilang.'};
    final url = Uri.parse('$_baseUrl/cash/transaction');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'type': type,
          'amount': amount,
          'description': description,
        }),
      );
      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message'] ?? 'Transaksi berhasil dicatat.'};
      } 
      else if (response.statusCode == 400 || data['success'] == false) {
        return {'success': false, 'message': data['message'] ?? 'Validasi input gagal.'};
      } 
      else {
        return {'success': false, 'message': 'Kesalahan server tak terduga: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error jaringan: $e'};
    }
  }

  // Menggantikan postCloseShift
  // UPDATED: Menerima amount, onBehalfOfId, notes, dan proofImagePath (foto bukti fisik)
  Future<Map<String, dynamic>> postDepositToMain(
    int amount, {
    int? onBehalfOfId,
    String? notes,
    String? proofImagePath,
  }) async {
    if (_token == null) return {'success': false, 'message': 'Token hilang.'};
    final url = Uri.parse('$_baseUrl/cash/deposit-to-main');

    try {
      if (proofImagePath != null && proofImagePath.isNotEmpty) {
        var request = http.MultipartRequest('POST', url)
          ..headers['Authorization'] = 'Bearer $_token'
          ..headers['Accept'] = 'application/json'
          ..fields['amount'] = amount.toString();

        if (onBehalfOfId != null) {
          request.fields['on_behalf_of'] = onBehalfOfId.toString();
        }
        if (notes != null && notes.isNotEmpty) {
          request.fields['notes'] = notes;
        }

        request.files.add(await http.MultipartFile.fromPath('proof_image', proofImagePath));

        var streamedResponse = await request.send();
        final responseBody = await streamedResponse.stream.bytesToString();
        
        Map<String, dynamic> data;
        try {
          data = json.decode(responseBody);
        } catch (_) {
          return {
            'success': false,
            'message': 'Gagal (${streamedResponse.statusCode}): Respon server bukan format JSON.',
          };
        }

        if ((streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) && data['success'] == true) {
          return {'success': true, 'message': data['message'] ?? 'Setoran berhasil dicatat.', 'data': data['data']};
        } else {
          return {'success': false, 'message': data['message'] ?? 'Setoran gagal.'};
        }
      } else {
        final Map<String, dynamic> body = {
          'amount': amount,
        };
        if (onBehalfOfId != null) {
          body['on_behalf_of'] = onBehalfOfId;
        }
        if (notes != null && notes.isNotEmpty) {
          body['notes'] = notes;
        }

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
            'Accept': 'application/json',
          },
          body: json.encode(body),
        );

        final Map<String, dynamic> data = json.decode(response.body);

        if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
          return {'success': true, 'message': data['message'] ?? 'Setoran berhasil dicatat.', 'data': data['data']};
        } else {
          return {'success': false, 'message': data['message'] ?? 'Setoran gagal. Cek saldo kasir.'};
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Error jaringan: $e'};
    }
  }

  // ==========================================================
  // --- ENDPOINT SHIFT KASIR & REKONSILIASI ---
  // ==========================================================

  Future<Map<String, dynamic>?> getCurrentShift() async {
    if (_token == null) return null;
    final url = Uri.parse('$_baseUrl/shifts/current');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> postCloseShift({
    required int actualCash,
    String? notes,
  }) async {
    if (_token == null) return {'success': false, 'message': 'Token hilang.'};
    final url = Uri.parse('$_baseUrl/shifts/close');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
        body: json.encode({
          'actual_cash': actualCash,
          if (notes != null) 'notes': notes,
        }),
      );
      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      }
      return {'success': false, 'message': data['message'] ?? 'Gagal menutup shift.'};
    } catch (e) {
      return {'success': false, 'message': 'Error jaringan: $e'};
    }
  }

  Future<List<dynamic>> getShiftHistory({String? date}) async {
    if (_token == null) return [];
    String query = date != null ? '?date=$date' : '';
    final url = Uri.parse('$_baseUrl/shifts/history$query');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getDepositHistory({String? date}) async {
    if (_token == null) return [];
    String query = date != null ? '?date=$date' : '';
    final url = Uri.parse('$_baseUrl/shifts/deposits$query');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }


  Future<Map<String, dynamic>?> getCashDashboard({
    String? startDate,
    String? endDate,
  }) async {
    if (_token == null) return null;
    
    final Map<String, dynamic> queryParams = {};
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;

    final url = Uri.parse('$_baseUrl/cash/dashboard').replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==========================================================
  // --- ENDPOINT OWNER (DASHBOARD & TRANSAKSI) ---
  // ==========================================================
  
  // --- ENDPOINT GET /owner/dashboard (Khusus Owner) ---
  Future<Map<String, dynamic>?> getOwnerDashboard({
    String? startDate,
    String? endDate,
  }) async {
    if (_token == null) return null;

    final Map<String, dynamic> queryParams = {};
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;

    final url = Uri.parse('$_baseUrl/owner/dashboard').replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data; 
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- ENDPOINT GET /owner/transactions (Riwayat Lengkap) ---
  Future<Map<String, dynamic>?> getOwnerTransactions({
    required String startDate,
    required String endDate,
    int page = 1,
  }) async {
    if (_token == null) return null;
    
    final Map<String, dynamic> queryParams = {
      'start_date': startDate,
      'end_date': endDate,
      'page': page.toString(),
    };

    final url = Uri.parse('$_baseUrl/owner/transactions').replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data; 
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- ENDPOINT GET /owner/inventory (Inventory Analitik) ---
  Future<Map<String, dynamic>?> getOwnerInventory({String? search}) async {
    if (_token == null) return null;

    final Map<String, dynamic> queryParams = {};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final url = Uri.parse('$_baseUrl/owner/inventory').replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data; 
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- ENDPOINT ADJUST STOCK (RESTOCK/DAMAGE) ---
  Future<Map<String, dynamic>> adjustStock({
    required int productId,
    required int quantity,
    required String reason, // 'RESTOCK', 'DAMAGE', 'RETURN', 'ADJUSTMENT'
    String? notes,
    String? direction, // 'in' or 'out' (required if reason is ADJUSTMENT)
  }) async {
    if (_token == null) return {'success': false, 'message': 'Token hilang.'};
    final url = Uri.parse('$_baseUrl/inventory/adjust');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
        body: json.encode({
          'product_id': productId,
          'quantity': quantity,
          'reason': reason,
          'notes': notes,
          'direction': direction,
        }),
      );

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message'] ?? 'Stok berhasil diupdate.'};
      } 
      else {
        return {'success': false, 'message': data['message'] ?? 'Gagal update stok.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error jaringan: $e'};
    }
  }

  // ==========================================================
  // --- ENDPOINT BELANJA KASIR (Uang Laci -> Stok / Operasional) ---
  // ==========================================================

  Future<Map<String, dynamic>> postCashierPurchase({
    required String category, // 'STOCK' or 'OPERATIONAL'
    required int amount,
    required String description,
    int? productId,
    int? quantity,
    String? proofImagePath,
  }) async {
    if (_token == null) return {'success': false, 'message': 'Token hilang.'};
    final url = Uri.parse('$_baseUrl/purchases');

    try {
      if (proofImagePath != null && proofImagePath.isNotEmpty) {
        var request = http.MultipartRequest('POST', url)
          ..headers['Authorization'] = 'Bearer $_token'
          ..headers['Accept'] = 'application/json'
          ..fields['category'] = category
          ..fields['amount'] = amount.toString()
          ..fields['description'] = description;

        if (productId != null) {
          request.fields['product_id'] = productId.toString();
        }
        if (quantity != null) {
          request.fields['quantity'] = quantity.toString();
        }

        request.files.add(await http.MultipartFile.fromPath('proof_image', proofImagePath));

        var streamedResponse = await request.send();
        final responseBody = await streamedResponse.stream.bytesToString();
        
        Map<String, dynamic> data;
        try {
          data = json.decode(responseBody);
        } catch (_) {
          return {
            'success': false,
            'message': 'Gagal (${streamedResponse.statusCode}): Respon server bukan format JSON.',
          };
        }

        if ((streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) && data['success'] == true) {
          return {'success': true, 'message': data['message'] ?? 'Belanja berhasil dicatat!', 'data': data['data']};
        } else {
          return {'success': false, 'message': data['message'] ?? 'Gagal mencatat belanja.'};
        }
      } else {
        final Map<String, dynamic> body = {
          'category': category,
          'amount': amount,
          'description': description,
        };
        if (productId != null) body['product_id'] = productId;
        if (quantity != null) body['quantity'] = quantity;

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
            'Accept': 'application/json',
          },
          body: json.encode(body),
        );

        final Map<String, dynamic> data = json.decode(response.body);

        if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
          return {'success': true, 'message': data['message'] ?? 'Belanja berhasil dicatat!', 'data': data['data']};
        } else {
          return {'success': false, 'message': data['message'] ?? 'Gagal mencatat belanja.'};
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Error jaringan: $e'};
    }
  }

  Future<Map<String, dynamic>?> getCashierPurchases({String? date, String? category, int page = 1}) async {
    if (_token == null) return null;
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
    };
    if (date != null && date.isNotEmpty) queryParams['date'] = date;
    if (category != null && category.isNotEmpty) queryParams['category'] = category;

    final url = Uri.parse('$_baseUrl/purchases/history').replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}