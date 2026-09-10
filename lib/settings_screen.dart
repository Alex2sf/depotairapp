import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'api_service.dart';
import 'role_based_router.dart';
import 'printer_service.dart';
import 'widgets/custom_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  final PrinterService _printerService = PrinterService(); 

  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeSloganController = TextEditingController();

  List<BluetoothInfo> _devices = [];
  String? _selectedMac;
  bool _isPrinterConnected = false;
  bool _isLoadingPrinter = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initPrinter(); 
  }

  Future<void> _loadData() async {
    final profile = await _apiService.getProfile();
    final prefs = await SharedPreferences.getInstance();
    
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _storeNameController.text = prefs.getString('store_name') ?? 'Warung';
        _storeSloganController.text = prefs.getString('store_slogan') ?? 'Belanja Murah & Lengkap';
        _isLoading = false;
      });
    }
  }

  Future<void> _initPrinter() async {
    final devices = await _printerService.getPairedDevices();
    final isConnected = await _printerService.isConnected();
    final prefs = await SharedPreferences.getInstance();
    final savedMac = prefs.getString('printer_mac');

    if (mounted) {
      setState(() {
        _devices = devices;
        _isPrinterConnected = isConnected;
        _selectedMac = savedMac;
      });
    }
  }

  Future<void> _connectPrinter(String mac) async {
    setState(() => _isLoadingPrinter = true);
    final success = await _printerService.connect(mac);
    
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_mac', mac); 
    }

    if (mounted) {
      setState(() {
        _isPrinterConnected = success;
        _isLoadingPrinter = false;
        _selectedMac = mac;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Printer Terhubung!' : 'Gagal Konek'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _disconnectPrinter() async {
    await _printerService.disconnect();
    if (mounted) setState(() => _isPrinterConnected = false);
  }

  Future<void> _testPrint() async {
    final success = await _printerService.printTest();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal Print. Cek koneksi / Kertas.')),
      );
    }
  }

  Future<void> _saveStoreSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('store_name', _storeNameController.text);
    await prefs.setString('store_slogan', _storeSloganController.text);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Info Toko Disimpan!')));
  }

  Future<void> _handleLogout() async {
    final confirmed = await showLogoutDialog(context);

    if (!confirmed) return;
    await _apiService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleBasedRouter()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    final role = (_userProfile?['role'] ?? '').toString().toLowerCase();
    final isOwner = role == 'owner' || role == 'admin';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. PROFIL HEADER
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      (_userProfile?['name']?[0] ?? 'U').toUpperCase(),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userProfile?['name'] ?? 'Pengguna', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4)
                        ),
                        child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      )
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. PRINTER SECTION (KASIR ONLY)
            if (!isOwner) ...[
              _buildSectionTitle('Perangkat'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isPrinterConnected ? Colors.green.shade50 : Colors.red.shade50,
                          shape: BoxShape.circle
                        ),
                        child: Icon(Icons.print, color: _isPrinterConnected ? Colors.green : Colors.red),
                      ),
                      title: Text(_isPrinterConnected ? 'Printer Terhubung' : 'Printer Terputus', 
                        style: TextStyle(fontWeight: FontWeight.bold, color: _isPrinterConnected ? Colors.green : Colors.red)),
                      subtitle: Text(_selectedMac ?? 'Klik refresh untuk cari'),
                      trailing: _isPrinterConnected
                          ? IconButton(icon: const Icon(Icons.link_off, color: Colors.red), onPressed: _disconnectPrinter)
                          : IconButton(icon: const Icon(Icons.refresh, color: Colors.blue), onPressed: _initPrinter),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                             if (_devices.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12.0),
                                  child: Text('Bluetooth mati / tidak ada perangkat.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8)
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _devices.any((d) => d.macAdress == _selectedMac) ? _selectedMac : null,
                                      hint: const Text('Pilih Thermal Printer', style: TextStyle(fontSize: 13)),
                                      isExpanded: true,
                                      items: _devices.map((d) => DropdownMenuItem(value: d.macAdress, child: Text(d.name))).toList(),
                                      onChanged: (val) { if (val != null) _connectPrinter(val); },
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isPrinterConnected && !_isLoadingPrinter ? _testPrint : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade50,
                                    foregroundColor: Colors.blue,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12)
                                  ),
                                  icon: const Icon(Icons.receipt_long, size: 18),
                                  label: _isLoadingPrinter 
                                    ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2)) 
                                    : const Text('Test Print Struk'),
                                ),
                              ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 3. STORE SETTINGS (OWNER ONLY)
            if (isOwner) ...[
              _buildSectionTitle('Info Toko'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _storeNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Toko',
                        prefixIcon: Icon(Icons.store),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _storeSloganController,
                      decoration: const InputDecoration(
                        labelText: 'Slogan / Footer Struk',
                        prefixIcon: Icon(Icons.text_fields),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveStoreSettings, 
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('Simpan Perubahan')
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 4. ACCOUNT ACTIONS
            _buildSectionTitle('Akun'),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, 
                  foregroundColor: Colors.red,
                  elevation: 0,
                  side: BorderSide(color: Colors.red.shade100),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar dari Aplikasi'),
              ),
            ),
            
            const SizedBox(height: 20),
            Center(
               child: Text(
                 'Versi Aplikasi 1.0.0',
                 style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
               ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        ],
      ),
    );
  }
}