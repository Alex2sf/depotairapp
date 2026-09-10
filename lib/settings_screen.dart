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
        _storeNameController.text = prefs.getString('store_name') ?? 'Depot Air Minum';
        _storeSloganController.text =
            prefs.getString('store_slogan') ?? 'Segar, Bersih & Higienis';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(success ? 'Printer Thermal Terhubung!' : 'Gagal Menghubungkan Printer'),
            ],
          ),
          backgroundColor: success ? const Color(0xFF16A34A) : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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
        SnackBar(
          content: const Text('Gagal Print. Periksa koneksi Bluetooth atau kertas.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _saveStoreSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('store_name', _storeNameController.text.trim());
    await prefs.setString('store_slogan', _storeSloganController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Informasi Depot Air Berhasil Disimpan!'),
            ],
          ),
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1F5F9),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0284C7)),
        ),
      );
    }

    final role = (_userProfile?['role'] ?? '').toString().toLowerCase();
    final isOwner = role == 'owner' || role == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // 1. MODERN HEADER GRADIENT
            _buildHeader(),

            // 2. PROFILE CARD (OVERLAPPING)
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildProfileCard(role),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3. STORE SETTINGS (OWNER & ADMIN)
                  if (isOwner) ...[
                    _buildSectionHeader(
                      title: "Informasi Depot",
                      subtitle: "Nama toko dan keterangan pada struk nota",
                    ),
                    const SizedBox(height: 12),
                    _buildStoreSettingsCard(),
                    const SizedBox(height: 24),
                  ],

                  // 4. THERMAL PRINTER SETTINGS
                  _buildSectionHeader(
                    title: "Perangkat Thermal Printer",
                    subtitle: "Koneksi Bluetooth untuk cetak struk kasir",
                  ),
                  const SizedBox(height: 12),
                  _buildPrinterCard(),
                  const SizedBox(height: 24),

                  // 5. APP INFO & SYSTEM
                  _buildSectionHeader(
                    title: "Sistem & Aplikasi",
                    subtitle: "Detail versi dan server",
                  ),
                  const SizedBox(height: 12),
                  _buildAppInfoCard(),
                  const SizedBox(height: 24),

                  // 6. LOGOUT BUTTON
                  _buildLogoutButton(),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 54, 22, 54),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0A2540), // Deep Navy
            Color(0xFF075985), // Ocean Blue
            Color(0xFF0284C7), // Sky Blue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded, size: 16, color: Colors.cyanAccent),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Konfigurasi & Akun",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                "Pengaturan",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings_suggest_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(String role) {
    final name = _userProfile?['name'] ?? 'Pengguna';
    final email = _userProfile?['email'] ?? '-';
    final initial = (name.isNotEmpty ? name[0] : 'U').toUpperCase();

    Color roleBg;
    Color roleText;
    if (role == 'owner' || role == 'admin') {
      roleBg = const Color(0xFFEEF2FF);
      roleText = const Color(0xFF4F46E5);
    } else {
      roleBg = const Color(0xFFE0F2FE);
      roleText = const Color(0xFF0284C7);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.1),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: roleText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Nama Depot Air",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _storeNameController,
            decoration: InputDecoration(
              hintText: 'Contoh: Depot Air Tirta Sehat',
              prefixIcon: const Icon(Icons.storefront_rounded, color: Color(0xFF0284C7), size: 20),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Slogan / Catatan Kaki Struk",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _storeSloganController,
            decoration: InputDecoration(
              hintText: 'Contoh: Terima Kasih Atas Kunjungan Anda!',
              prefixIcon: const Icon(Icons.short_text_rounded, color: Color(0xFF0284C7), size: 20),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _saveStoreSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text(
                'Simpan Informasi Toko',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Status Printer
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isPrinterConnected ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.print_rounded,
                    color: _isPrinterConnected ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPrinterConnected ? 'Printer Terhubung' : 'Printer Belum Konek',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _isPrinterConnected
                              ? const Color(0xFF15803D)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedMac ?? 'Pilih perangkat Bluetooth di bawah',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (_isPrinterConnected)
                  IconButton(
                    icon: const Icon(Icons.link_off_rounded, color: Colors.red),
                    onPressed: _disconnectPrinter,
                    tooltip: 'Putuskan Printer',
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0284C7)),
                    onPressed: _initPrinter,
                    tooltip: 'Pindai Ulang',
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                if (_devices.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bluetooth_disabled_rounded, size: 18, color: Color(0xFFD97706)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bluetooth belum aktif atau belum ada printer yang di-pair.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _devices.any((d) => d.macAdress == _selectedMac) ? _selectedMac : null,
                        hint: const Text('Pilih Printer Bluetooth', style: TextStyle(fontSize: 13)),
                        isExpanded: true,
                        items: _devices
                            .map(
                              (d) => DropdownMenuItem(
                                value: d.macAdress,
                                child: Text(d.name, style: const TextStyle(fontSize: 13)),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) _connectPrinter(val);
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isPrinterConnected && !_isLoadingPrinter ? _testPrint : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE0F2FE),
                      foregroundColor: const Color(0xFF0284C7),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: _isLoadingPrinter
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0284C7),
                            ),
                          )
                        : const Text(
                            'Test Cetak Struk',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.dns_rounded,
            title: "Server API",
            value: "Online • hydroexpert.my.id",
            iconColor: const Color(0xFF16A34A),
          ),
          const Divider(height: 1, indent: 60),
          _buildInfoRow(
            icon: Icons.water_drop_rounded,
            title: "Mode Sistem",
            value: "Depot Air POS & Logistik",
            iconColor: const Color(0xFF0284C7),
          ),
          const Divider(height: 1, indent: 60),
          _buildInfoRow(
            icon: Icons.verified_rounded,
            title: "Versi Aplikasi",
            value: "v1.0.0 (Production)",
            iconColor: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 14),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFFCA5A5)), // Red 300
          backgroundColor: const Color(0xFFFEF2F2), // Red 50
          foregroundColor: const Color(0xFFDC2626), // Red 600
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text(
          'Keluar dari Akun (Logout)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}