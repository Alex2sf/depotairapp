import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'role_based_router.dart'; 

class CloseShiftScreen extends StatefulWidget {
  const CloseShiftScreen({super.key});

  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController(); 
  
  bool _isLoading = false;
  bool _isFetching = true;

  int _currentCashierBalance = 0;
  List<Map<String, dynamic>> _depositableUsers = [];
  int? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
 
  Future<void> _fetchInitialData() async {
    setState(() => _isFetching = true);
    
    // 1. Get Balance
    final balanceResult = await _apiService.getCashDashboard();
    
    // 2. Get Users
    final usersResult = await _apiService.getDepositableUsers();
    final userProfile = await _apiService.getProfile();

    if (mounted) {
      // Set Balance
      if (balanceResult != null && balanceResult['success'] == true) {
        _currentCashierBalance = balanceResult['kas_kasir'] ?? 0;
      }

      // Set Users
      final currentUserId = userProfile?['id'] as int?;
      final currentUserName = userProfile?['name'] ?? 'Saya Sendiri';
      final defaultUserOption = {'id': currentUserId, 'name': '$currentUserName (Saya)'};
      
      _depositableUsers = [
          defaultUserOption,
          ...usersResult.where((user) => user['id'] != currentUserId)
      ];
      _selectedUserId = currentUserId;

      setState(() => _isFetching = false);
    }
  }

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih user atas nama setoran!')));
        return;
    }
    
    setState(() => _isLoading = true);

    final cleanAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(cleanAmount) ?? 0;
    
    if (amount > _currentCashierBalance) {
         if(mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saldo Kasir ${_formatCurrency(_currentCashierBalance)} tidak cukup.'),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
         }
         return;
    }

    final result = await _apiService.postDepositToMain(
        amount, 
        onBehalfOfId: _selectedUserId 
    );

    if (mounted) {
      setState(() => _isLoading = false);
      
      final success = result['success'] as bool? ?? false;
      final message = result['message'] as String? ?? 'Terjadi kesalahan.';

      if (success) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        final newCashierBalance = data['saldo_kasir'] ?? 0; 
        final newMainBalance = data['saldo_kas_besar'] ?? 0; 
        
        _showSuccessDialog(amount, newCashierBalance, newMainBalance, message);
        _amountController.clear();
        _fetchInitialData(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $message'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _formatInputCurrency(String value) {
    if (value.isEmpty) return;
    String clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    double number = double.parse(clean);
    String formatted = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(number).trim();
    
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _setSetorSemua() {
    // Fill input with current balance
    String formatted = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(_currentCashierBalance).trim();
    _amountController.text = formatted;
  }

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  void _showSuccessDialog(int amount, int newCashierBalance, int newMainBalance, String apiMessage) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Setoran Sukses')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(apiMessage, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            _buildDialogRow('Disetor', _formatCurrency(amount), Colors.orange),
            _buildDialogRow('Sisa Kasir', _formatCurrency(newCashierBalance), Colors.black),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); 
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RoleBasedRouter()),
                (route) => false,
              );
            },
            child: const Text('OK, TUTUP'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value, Color color) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
              ],
          ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Tutup Shift', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isFetching
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // USER DROPDOWN
                      DropdownButtonFormField<int>(
                        value: _selectedUserId,
                        decoration: InputDecoration(
                          labelText: 'Setor Atas Nama',
                          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          prefixIcon: const Icon(Icons.person_outline, color: Colors.orange),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                        ),
                        items: _depositableUsers.map((user) {
                          return DropdownMenuItem<int>(
                            value: user['id'] as int?,
                            child: Text(user['name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (newValue) => setState(() => _selectedUserId = newValue),
                        validator: (value) => value == null ? 'Wajib dipilih' : null,
                      ),
                      const SizedBox(height: 32),

                      // INFO SALDO KASIR
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [Colors.orange.shade800, Colors.orange.shade500],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                                BoxShadow(color: Colors.orange.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 10))
                            ]
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                const Row(
                                    children: [
                                        Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 20),
                                        SizedBox(width: 8),
                                        Text('Saldo Fisik Kasir (Saat Ini)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
                                    ],
                                ),
                                const SizedBox(height: 8),
                                Text(_formatCurrency(_currentCashierBalance), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 8),
                                const Text('Uang ini harus diserahkan ke Kas Besar saat tutup shift.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                            ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // HERO INPUT
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                              Text('Jumlah Disetor', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                              TextButton(
                                  onPressed: _setSetorSemua, 
                                  child: const Text('Setor Semua', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
                              )
                          ],
                      ),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.orange),
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
                          border: InputBorder.none,
                          hintText: '0',
                          hintStyle: TextStyle(fontSize: 40, color: Colors.grey.shade300),
                        ),
                        onChanged: _formatInputCurrency,
                        validator: (value) {
                            if (value == null || value.isEmpty) return 'Wajib diisi';
                            final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
                            // Allow 0 for closing shift without deposit
                            if (int.tryParse(clean) == null || int.tryParse(clean)! < 0) return 'Tidak valid';
                            return null;
                        },
                      ),
                      const Divider(thickness: 1.5),
                      
                      const SizedBox(height: 48),

                      // SUBMIT
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitDeposit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 5,
                            shadowColor: Colors.orange.withOpacity(0.4),
                          ),
                          child: _isLoading 
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : const Text('TUTUP SHIFT & SETOR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
    );
  }
}