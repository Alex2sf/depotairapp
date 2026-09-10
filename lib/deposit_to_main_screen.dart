import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class DepositToMainScreen extends StatefulWidget {
  const DepositToMainScreen({super.key});

  @override
  State<DepositToMainScreen> createState() => _DepositToMainScreenState();
}

class _DepositToMainScreenState extends State<DepositToMainScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isFetching = true;

  int _currentCashierBalance = 0;
  List<Map<String, dynamic>> _depositableUsers = [];
  int? _selectedUserId;
  File? _proofImage;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isFetching = true);

    final balanceResult = await _apiService.getCashDashboard();
    final usersResult = await _apiService.getDepositableUsers();
    final userProfile = await _apiService.getProfile();

    if (mounted) {
      if (balanceResult != null && balanceResult['success'] == true) {
        _currentCashierBalance = balanceResult['kas_kasir'] ?? 0;
      }

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _proofImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pilih Sumber Foto Bukti',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('Kamera Langsung'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Galeri HP'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kasir atas nama setoran!')),
      );
      return;
    }

    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto bukti fisik setoran wajib dilampirkan! 📸'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final cleanAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(cleanAmount) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal setoran tidak valid!')),
      );
      return;
    }

    if (amount > _currentCashierBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saldo Kasir ${_formatCurrency(_currentCashierBalance)} tidak cukup.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.postDepositToMain(
      amount,
      onBehalfOfId: _selectedUserId,
      notes: _notesController.text.trim(),
      proofImagePath: _proofImage?.path,
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $message'),
            backgroundColor: Colors.red.shade700,
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

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  void _showSuccessDialog(int amount, int newCashierBalance, int newMainBalance, String apiMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Setoran Sukses', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(apiMessage, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            _buildDialogRow('Disetor ke Kas Besar', _formatCurrency(amount), Colors.green.shade800),
            _buildDialogRow('Sisa Kas Laci', _formatCurrency(newCashierBalance), Colors.orange.shade900),
            _buildDialogRow('Total Kas Besar', _formatCurrency(newMainBalance), Colors.blue.shade900),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true); // Kembali ke beranda
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK, SELESAI'),
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isOverTwoMillion = _currentCashierBalance >= 2000000;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Setor ke Kas Besar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BANNER PERINGATAN >= 2 JUTA
                    if (isOverTwoMillion)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Uang Laci Sudah Rp 2 Juta+',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Disarankan segera setor sebagian uang ke Kas Besar / Brankas agar laci tetap aman.',
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // KARTU SALDO LACI SEKARANG
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.indigo.shade800, Colors.indigo.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.indigo.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("SALDO UANG FISIK DI LACI", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Text(
                            _formatCurrency(_currentCashierBalance),
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text("Uang ini yang siap dipindahkan ke Kas Besar.", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // DROPDOWN KASIR
                    const Text("Kasir Penyetor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedUserId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.person, color: Colors.indigo),
                      ),
                      items: _depositableUsers.map((u) {
                        return DropdownMenuItem<int>(
                          value: u['id'] as int?,
                          child: Text(u['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedUserId = val),
                    ),
                    const SizedBox(height: 20),

                    // INPUT NOMINAL SETOR
                    const Text("Nominal yang Disetor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: _formatInputCurrency,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        hintText: '0',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: TextButton(
                          onPressed: () {
                            if (_currentCashierBalance > 300000) {
                              // Sisakan Rp 300rb untuk modal laci
                              int setor = _currentCashierBalance - 300000;
                              String formatted = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(setor).trim();
                              _amountController.text = formatted;
                            } else {
                              String formatted = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(_currentCashierBalance).trim();
                              _amountController.text = formatted;
                            }
                          },
                          child: const Text('Setor Aman (Sisa 300rb)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Nominal wajib diisi';
                        final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                        final numVal = int.tryParse(clean) ?? 0;
                        if (numVal <= 0) return 'Nominal harus lebih dari Rp 0';
                        if (numVal > _currentCashierBalance) return 'Melebihi saldo laci kasir!';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // UPLOAD FOTO BUKTI FISIK (WAJIB)
                    const Row(
                      children: [
                        Text("Foto Bukti Fisik Uang", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(width: 6),
                        Text("(Wajib 📸)", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _proofImage != null ? Colors.green : Colors.grey.shade400,
                            width: _proofImage != null ? 2 : 1,
                          ),
                          image: _proofImage != null
                              ? DecorationImage(image: FileImage(_proofImage!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _proofImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Ketuk untuk Ambil Foto Bukti Uang / Amplop",
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text("Foto uang di brankas / serah terima ke owner", style: TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              )
                            : Container(
                                alignment: Alignment.bottomRight,
                                padding: const EdgeInsets.all(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text("Ganti Foto", style: TextStyle(color: Colors.white, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // CATATAN TAMBAHAN
                    const Text("Catatan / Keterangan (Opsional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "Contoh: Diserahkan langsung ke Pak Bos / brankas laci 2",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // TOMBOL SUBMIT
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitDeposit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade800,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("SIMPAN & SETOR KE KAS BESAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
