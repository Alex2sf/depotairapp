import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class PrinterService {
  // 1. Cek Izin
  Future<bool> checkPermission() async {
    if (await Permission.bluetoothConnect.request().isGranted &&
        await Permission.bluetoothScan.request().isGranted) {
      return true;
    }
    var status = await Permission.bluetooth.request();
    return status.isGranted;
  }

  // 2. Ambil List Device
  Future<List<BluetoothInfo>> getPairedDevices() async {
    await checkPermission();
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  // 3. Connect
  Future<bool> connect(String macAddress) async {
    return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  // 4. Disconnect
  Future<bool> disconnect() async {
    return await PrintBluetoothThermal.disconnect;
  }

  // 5. Cek Status
  Future<bool> isConnected() async {
    return await PrintBluetoothThermal.connectionStatus;
  }

  // --- FUNGSI BARU: AUTO CONNECT ---
  Future<bool> autoConnect() async {
    if (await isConnected()) return true;

    final prefs = await SharedPreferences.getInstance();
    final savedMac = prefs.getString('printer_mac');

    if (savedMac != null && savedMac.isNotEmpty) {
      return await connect(savedMac);
    }
    return false;
  }

  // --- FUNGSI BARU: CETAK STRUK TRANSAKSI ---
  Future<bool> printReceipt(Map<String, dynamic> order) async {
    // 1. Pastikan Konek
    final connected = await autoConnect();
    if (!connected) return false;

    // 2. Siapkan Data
    final prefs = await SharedPreferences.getInstance();
    final storeName = prefs.getString('store_name') ?? 'Warung';
    final storeSlogan = prefs.getString('store_slogan') ?? 'Belanja Murah & Lengkap';

    final items = order['items'] as List<dynamic>? ?? [];
    final total = double.tryParse(order['total_amount'].toString()) ?? 0;
    final deliveryFee = double.tryParse(order['delivery_fee'].toString()) ?? 0;

    // Format Uang & Tanggal
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final date = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(date);

    // 3. Generate Bytes Struk
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += generator.reset();

    // HEADER
    bytes += generator.text(storeName,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += generator.text(storeSlogan,
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Telp/WA: 0877-2777-7302',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);

    // INFO ORDER
    bytes += generator.text('No: ${order['order_number']}', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(dateStr, styles: const PosStyles(align: PosAlign.center));
    
    // CUSTOMER INFO (BARU)
    final String cName = order['customer']?['name'] ?? order['customer_name'] ?? '-';
    final String cPhone = order['customer']?['phone_number'] ?? order['customer_phone'] ?? '-';
    
    if (cName != '-') {
      bytes += generator.feed(1);
      bytes += generator.text('Pelanggan: $cName');
      if (cPhone != '-') bytes += generator.text('HP: $cPhone');
    }

    bytes += generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center));

    // LIST ITEM
    for (var item in items) {
      final name = item['product_name'] ?? item['name'] ?? 'Item';
      final qty = item['quantity'] ?? item['qty'] ?? 0;
      final price = double.tryParse(item['price'].toString()) ?? 0;
      final subtotal = price * qty;

      // Baris 1: Nama Barang
      bytes += generator.text(name);
      // Baris 2: Qty x Harga ...... Total
      bytes += generator.row([
        PosColumn(
          text: '$qty x ${currency.format(price).replaceAll("Rp ", "")}',
          width: 8,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: currency.format(subtotal).replaceAll("Rp ", ""),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center));

    // TOTAL & BIAYA LAIN
    if (deliveryFee > 0) {
      bytes += generator.row([
        PosColumn(text: 'Ongkir', width: 6),
        PosColumn(text: currency.format(deliveryFee), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
        text: currency.format(total),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)
      ),
    ]);

    // FOOTER
    bytes += generator.feed(1);
    bytes += generator.text('Terima Kasih', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Simpan struk ini sebagai bukti', styles: const PosStyles(align: PosAlign.center));
    
    // --- UPDATE DI SINI (SOLUSI FEED KERTAS) ---
    // Memberi jarak kosong 3 baris ke bawah agar footer tidak terpotong pisau printer
    bytes += generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center));
    
    // Opsional: Kalau printer support auto-cut, nyalakan ini:
    // bytes += generator.cut();
    // -------------------------------------------

    // 4. Kirim ke Printer
    return await PrintBluetoothThermal.writeBytes(bytes);
  }

  // 6. Test Print
  Future<bool> printTest() async {
    bool connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) return false;
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.text('TEST KONEKSI OK', styles: const PosStyles(align: PosAlign.center, bold: true));
    
    // Feed test juga sebaiknya ditambah biar enak nyobeknya
    bytes += generator.feed(3); 
    
    return await PrintBluetoothThermal.writeBytes(bytes);
  }
}