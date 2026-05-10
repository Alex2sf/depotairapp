import 'package:flutter/material.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';

class CashTransactionScreen extends StatefulWidget {
  const CashTransactionScreen({super.key});

  @override
  State<CashTransactionScreen> createState() => _CashTransactionScreenState();
}

class _CashTransactionScreenState extends State<CashTransactionScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  String _transactionType = 'EXPENSE'; // EXPENSE or DEPOSIT
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  bool _isLoading = false;

  // Suggestion chips
  final List<String> _expenseSuggestions = ['Beli Bensin', 'Uang Makan', 'Beli Token Listrik', 'Beli Galon/Tutup', 'Perbaikan Alat', 'Lain-lain'];
  final List<String> _depositSuggestions = ['Modal Awal', 'Setoran Tambahan', 'Kembalian Salah', 'Lain-lain'];

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    // Remove non-digits for parsing
    final cleanAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(cleanAmount) ?? 0;

    final result = await _apiService.postCashTransaction(
      type: _transactionType,
      amount: amount,
      description: _descriptionController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);

      final success = result['success'] as bool;
      final message = result['message'] as String;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 8), Text(message)]), 
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 8), Text(message)]),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Currency formatter
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

  @override
  Widget build(BuildContext context) {
    final isExpense = _transactionType == 'EXPENSE';
    final themeColor = isExpense ? Colors.red : Colors.green;
    final suggestions = isExpense ? _expenseSuggestions : _depositSuggestions;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Catat Transaksi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOGGLE SWITCH
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16)
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(child: _buildToggleOption('PENGELUARAN', 'EXPENSE', Colors.red)),
                    Expanded(child: _buildToggleOption('PEMASUKAN', 'DEPOSIT', Colors.green)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 2. HERO AMOUNT INPUT
              Text('Jumlah Nominal', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: themeColor),
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
                    if (int.tryParse(clean) == null || int.tryParse(clean)! <= 0) return 'Tidak valid';
                    return null;
                },
              ),
              const Divider(thickness: 1.5),
              const SizedBox(height: 24),

              // 3. DESCRIPTION with SUGGESTIONS
              Text('Keterangan Transaksi', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((s) => ActionChip(
                  label: Text(s),
                  backgroundColor: Colors.grey.shade50,
                  side: BorderSide(color: Colors.grey.shade200),
                  labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  onPressed: () {
                    _descriptionController.text = s;
                  },
                )).toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  hintText: 'Ketik keterangan manual...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Keterangan wajib diisi' : null,
              ),

              const SizedBox(height: 40),

              // 4. SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                    shadowColor: themeColor.withOpacity(0.4),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Text(
                        isExpense ? 'CATAT PENGELUARAN' : 'CATAT PEMASUKAN', 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption(String label, String value, Color activeColor) {
    final bool isActive = _transactionType == value;
    return GestureDetector(
      onTap: () => setState(() => _transactionType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : []
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? activeColor : Colors.grey.shade500,
            fontSize: 13
          ),
        ),
      ),
    );
  }
}