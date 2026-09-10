import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'cart_model.dart';
import 'role_based_router.dart';
import 'printer_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final ApiService _apiService = ApiService();
  final PrinterService _printerService = PrinterService();

  // Fields
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _deliveryFeeController = TextEditingController(text: '0');
  final TextEditingController _additionalFeeController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _gmapsLinkController = TextEditingController();
  final TextEditingController _scheduleController = TextEditingController();
  final TextEditingController _preparedMinutesController = TextEditingController(); // Kosongkan default

  int? _customerId;
  String? _customerName;
  String _orderType = 'SELF_PICKUP';
  String _paymentType = 'TUNAI';
  DateTime? _deliverySchedule;
  bool _isScheduledDelivery = false; // false = Antar Sekarang, true = Jadwalkan Nanti
  int _deliveryEstMinutes = 30; // default 30 menit
  bool _isSavingCustomer = false;
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'id';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _deliveryFeeController.dispose();
    _additionalFeeController.dispose();
    _notesController.dispose();
    _scheduleController.dispose();
    _gmapsLinkController.dispose();
    _preparedMinutesController.dispose();
    super.dispose();
  }

  // --- UTILS ---
  String _formatRupiah(num amount) => NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(amount);

  // --- LOGIC ---
  Future<void> _processCreateOrSelectCustomer() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
        if (_customerId == null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama wajib diisi!'), backgroundColor: Colors.red));
        return;
    }
    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() => _isSavingCustomer = true);
    final result = await _apiService.searchOrCreateCustomer(
      name: name,
      phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(), 
      query: name,
      isNew: true, 
    );
    setState(() {
      _isSavingCustomer = false;
      if (result != null && result['success'] == true) {
        final customer = result['customer'];
        _customerId = customer['id'];
        _customerName = customer['name'];
        _nameController.text = customer['name'] ?? '';
        _phoneController.text = customer['phone_number'] ?? '';
        if (customer['address'] != '-' && customer['address'] != null) _addressController.text = customer['address'];
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
               children: [
                 const Icon(Icons.check_circle, color: Colors.white),
                 const SizedBox(width: 8),
                 Expanded(child: Text(result['message'] ?? "Data Pelanggan Tersimpan!", style: const TextStyle(fontWeight: FontWeight.bold))),
               ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          )
        );
      } else {
        // ERROR HANDLER
        showDialog(
           context: context,
           builder: (ctx) => AlertDialog(
              title: const Text("Gagal Simpan"),
              content: Text(result?['message'] ?? 'Gagal menghubungi server'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
           )
        );
      }
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 30)));
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (pickedTime == null) return;
    
    final finalDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
    setState(() {
      _deliverySchedule = finalDateTime;
      _scheduleController.text = DateFormat('dd MMM HH:mm').format(finalDateTime);
    });
  }

  Future<void> _attemptCheckout(CartModel cart) async {
    if (_nameController.text.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama Pelanggan Wajib Diisi!'), backgroundColor: Colors.red));
         return;
    }
    // Auto-save customer if not yet saved but ID is null
    if (_customerId == null) await _processCreateOrSelectCustomer();
    if (!mounted) return;
    if (_customerId == null) return; // Save failed

    if (cart.items.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keranjang Kosong!'))); 
         return; 
    }
    if (_orderType == 'DELIVERY') {
      if (_addressController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alamat Wajib Diisi untuk Delivery!'), backgroundColor: Colors.red),
        );
        return;
      }
      if (_isScheduledDelivery && _deliverySchedule == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jadwal Kirim Wajib Diisi!'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isCheckingOut = true);

    DateTime? scheduleToSend;
    if (_orderType == 'DELIVERY') {
      scheduleToSend = _isScheduledDelivery ? _deliverySchedule : DateTime.now();
    }

    final orderData = {
      'customer_id': _customerId,
      'order_type': _orderType,
      'payment_type': _paymentType,
      'delivery_address': _orderType == 'DELIVERY' ? _addressController.text.trim() : null,
      'address_link': _orderType == 'DELIVERY' 
          ? (_gmapsLinkController.text.trim().isEmpty ? null : _gmapsLinkController.text.trim()) 
          : null,
      'delivery_fee': _orderType == 'DELIVERY' ? (int.tryParse(_deliveryFeeController.text) ?? 0) : 0,
      'additional_fee': int.tryParse(_additionalFeeController.text) ?? 0,
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      'delivery_scheduled_at': scheduleToSend?.toIso8601String(), 
      'prepared_minutes': _orderType == 'DELIVERY' ? _deliveryEstMinutes : null,
      'items': cart.items.map((i) => {'product_id': i.id, 'quantity': i.quantity}).toList(),
    };

    final result = await _apiService.checkoutOrder(orderData);
    setState(() => _isCheckingOut = false);

    if (!mounted) return;

    if (result != null && result['success'] == true) {
      if (result['is_offline'] == true) {
        cart.clearCart();
        _showOfflineSuccessDialog(result['message']);
        return;
      }
      final order = result['order'];
      // PRINT removed as per request (moved to Order History > Complete)
      // try {
      //     await _printerService.printReceipt(order);
      // } catch(e) { /* ignore */ }
      
      cart.clearCart();
      _showSuccessDialog(order);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result?['message'] ?? 'Gagal Checkout'), backgroundColor: Colors.red));
    }
  }

  void _showOfflineSuccessDialog(String message) {
     showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
           const Icon(Icons.cloud_off, color: Colors.orange, size: 80),
           const SizedBox(height: 16),
           const Text("Order Disimpan Offline", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
           const SizedBox(height: 8),
           Text(message, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
           const SizedBox(height: 20),
           SizedBox(
             width: double.infinity,
             child: ElevatedButton(
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                 onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const RoleBasedRouter()), (r)=>false),
                 child: const Text("Mengerti")
             ),
           )
        ]),
      )
    );
  }

  void _showSuccessDialog(Map<String, dynamic> order) {
    bool isPickup = _orderType == 'SELF_PICKUP';
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
           Icon(
             isPickup ? Icons.check_circle : Icons.delivery_dining, 
             color: isPickup ? Colors.green : Colors.blue.shade700, 
             size: 70,
           ),
           const SizedBox(height: 14),
           Text(
             isPickup ? "Pesanan Selesai!" : "Order Berhasil Dibuat!", 
             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
           ),
           const SizedBox(height: 4),
           Text("#${order['order_number']}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
           const SizedBox(height: 10),
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
             decoration: BoxDecoration(
               color: isPickup ? Colors.green.shade50 : Colors.blue.shade50,
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: isPickup ? Colors.green.shade200 : Colors.blue.shade200),
             ),
             child: Text(
               isPickup ? "⚡ AMBIL SENDIRI • STATUS COMPLETE" : "🚚 DIANTAR • MENUNGGU KURIR",
               style: TextStyle(
                 fontSize: 11, 
                 fontWeight: FontWeight.bold, 
                 color: isPickup ? Colors.green.shade800 : Colors.blue.shade800,
               ),
             ),
           ),
           const SizedBox(height: 20),
           SizedBox(
             width: double.infinity,
             child: ElevatedButton(
                 style: ElevatedButton.styleFrom(
                   backgroundColor: isPickup ? Colors.green : Colors.blue.shade800,
                   foregroundColor: Colors.white,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                   padding: const EdgeInsets.symmetric(vertical: 12),
                 ),
                 onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                   MaterialPageRoute(builder: (_) => const RoleBasedRouter()), 
                   (r) => false,
                 ),
                 child: const Text("Selesai & Ke Beranda", style: TextStyle(fontWeight: FontWeight.bold))
             ),
           )
        ]),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartModel>(context);
    final deliveryFee = _orderType == 'DELIVERY' ? (int.tryParse(_deliveryFeeController.text) ?? 0) : 0;
    final additionalFee = int.tryParse(_additionalFeeController.text) ?? 0;
    final total = cart.subtotal + deliveryFee + additionalFee;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          children: [
            _buildCustomerCard(),
            const SizedBox(height: 16),
            _buildOrderTypeCard(),
            const SizedBox(height: 16),
            _buildPaymentCard(),
            const SizedBox(height: 16),
            _buildSummaryCard(cart, deliveryFee, additionalFee, total),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0,-5))]),
        child: SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800, 
              foregroundColor: Colors.white, // FIX: Paksa teks jadi putih
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: _isCheckingOut ? null : () => _attemptCheckout(cart),
            child: _isCheckingOut 
              ? const CircularProgressIndicator(color: Colors.white)
              : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("PROSES BAYAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Rp ${_formatRupiah(total)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return _card(
      title: 'INFO PELANGGAN',
      icon: Icons.person,
      child: Column(children: [
        Row(children: [
          Expanded(child: _input(_nameController, "Nama Pelanggan", icon: Icons.perm_identity)),
          const SizedBox(width: 10),
          Expanded(child: _input(_phoneController, "No HP", icon: Icons.phone, type: TextInputType.phone)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isSavingCustomer ? null : _processCreateOrSelectCustomer,
            icon: const Icon(Icons.save),
            label: Text(_customerId == null ? "Simpan Data Pelanggan" : "Update Data Pelanggan"),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        )
      ]),
    );
  }

  Widget _buildOrderTypeCard() {
    bool isDelivery = _orderType == 'DELIVERY';
    return _card(
      title: 'METODE PENGAMBILAN',
      icon: isDelivery ? Icons.delivery_dining : Icons.storefront,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 45,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              _toggleBtn('📦 Ambil Sendiri', !isDelivery, () => setState(() => _orderType = 'SELF_PICKUP')),
              _toggleBtn('🚚 Diantar (Delivery)', isDelivery, () => setState(() => _orderType = 'DELIVERY')),
            ]),
          ),
          const SizedBox(height: 14),

          if (!isDelivery) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt, color: Colors.green.shade700, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ambil Langsung di Depot',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Status langsung SELESAI (COMPLETE) tanpa antrean kirim / estimasi waktu.',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Pilihan Waktu Kirim',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _isScheduledDelivery = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: !_isScheduledDelivery ? Colors.blue.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: !_isScheduledDelivery ? Colors.blue.shade700 : Colors.grey.shade300,
                          width: !_isScheduledDelivery ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.electric_bolt, 
                            size: 16, 
                            color: !_isScheduledDelivery ? Colors.blue.shade700 : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Antar Sekarang',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !_isScheduledDelivery ? Colors.blue.shade800 : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() => _isScheduledDelivery = true);
                      if (_deliverySchedule == null) _pickDateTime();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _isScheduledDelivery ? Colors.blue.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isScheduledDelivery ? Colors.blue.shade700 : Colors.grey.shade300,
                          width: _isScheduledDelivery ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule, 
                            size: 16, 
                            color: _isScheduledDelivery ? Colors.blue.shade700 : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Jadwalkan Nanti',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isScheduledDelivery ? Colors.blue.shade800 : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!_isScheduledDelivery) ...[
              Row(
                children: [
                  Text(
                    'Estimasi Tiba: ',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  for (int mins in [30, 45, 60]) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(
                          '$mins Mnt', 
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.bold, 
                            color: _deliveryEstMinutes == mins ? Colors.white : Colors.black87,
                          ),
                        ),
                        selected: _deliveryEstMinutes == mins,
                        selectedColor: Colors.blue.shade700,
                        backgroundColor: Colors.grey.shade100,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onSelected: (val) {
                          if (val) setState(() => _deliveryEstMinutes = mins);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              InkWell(
                onTap: _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, size: 20, color: Colors.blue.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _deliverySchedule == null
                              ? "Klik untuk Pilih Tanggal & Jam Pengantaran"
                              : "Jadwal: ${DateFormat('EEE, dd MMM yyyy • HH:mm').format(_deliverySchedule!)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _deliverySchedule == null ? Colors.blue.shade900 : Colors.black87,
                          ),
                        ),
                      ),
                      const Icon(Icons.edit, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),
            _input(_addressController, "Alamat Lengkap Pengantaran *", icon: Icons.location_on, maxLines: 2),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _input(
                    _deliveryFeeController, 
                    "Ongkos Kirim (Rp)", 
                    icon: Icons.motorcycle, 
                    type: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _input(
              _gmapsLinkController, 
              "Link Google Maps (Opsional)", 
              icon: Icons.map_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return _card(
      title: 'PEMBAYARAN',
      icon: Icons.payment,
      child: Column(
        children: [
          Row(children: [
            _payBtn('TUNAI', Icons.money),
            const SizedBox(width: 8),
            _payBtn('TRANSFER', Icons.account_balance),
            const SizedBox(width: 8),
            _payBtn('QRIS', Icons.qr_code),
            const SizedBox(width: 8),
            _payBtn('CORPORATE', Icons.business),
          ]),
          if (_paymentType == 'TRANSFER')
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: SelectableText.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: "Silakan transfer ke rekening:\n", style: TextStyle(color: Colors.black54, fontSize: 12)),
                    TextSpan(text: "BCA 8620658180\n", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade800)),
                    const TextSpan(text: "An. Fadli Ardi\n\n", style: TextStyle(fontWeight: FontWeight.bold)),
                    const TextSpan(text: "*Harap upload bukti transfer setelah checkout.", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: Colors.red)),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildSummaryCard(CartModel cart, int fee, int extra, num total) {
    return _card(
      title: 'RINGKASAN',
      icon: Icons.receipt,
      child: Column(children: [
         ...cart.items.map((i) => Padding(
           padding: const EdgeInsets.only(bottom: 8),
           child: Row(
             children: [
               // Qty Controls
               InkWell(
                 onTap: () => cart.updateQuantity(i.id, i.quantity - 1),
                 child: Container(
                   padding: const EdgeInsets.all(4),
                   decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                   child: const Icon(Icons.remove, size: 16, color: Colors.black),
                 ),
               ),
               const SizedBox(width: 12),
               Text("${i.quantity}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
               const SizedBox(width: 12),
               InkWell(
                 onTap: () => cart.updateQuantity(i.id, i.quantity + 1),
                 child: Container(
                   padding: const EdgeInsets.all(4),
                   decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                   child: Icon(Icons.add, size: 16, color: Colors.blue.shade700),
                 ),
               ),
               const SizedBox(width: 12),
               // Name & Price
               Expanded(child: Text(i.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
               Text(_formatRupiah(i.price * i.quantity), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
             ],
           ),
         )),
         const Divider(),
         _row("Subtotal", cart.subtotal),
         _row("Ongkir", fee),
         _row("Biaya Lain", extra),
         const SizedBox(height: 8),
         _input(_additionalFeeController, "Biaya Tambahan", type: TextInputType.number, icon: Icons.add_circle_outline),
         const SizedBox(height: 8),
         _input(_notesController, "Catatan...", icon: Icons.edit_note)
      ]),
    );
  }

  // --- WIDGET HELPER ---
  Widget _card({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         Row(children: [Icon(icon, size: 18, color: Colors.blue), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))]),
         const SizedBox(height: 16),
         child
      ]),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, {IconData? icon, TextInputType? type, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      onChanged: (_) => setState((){}),
    );
  }

  Widget _toggleBtn(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: active ? [const BoxShadow(color: Colors.black12, blurRadius: 2)] : null
          ),
          child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: active ? Colors.black : Colors.grey.shade600, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _payBtn(String type, IconData icon) {
    bool active = _paymentType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentType = type),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: active ? Colors.green.shade50 : Colors.white,
            border: Border.all(color: active ? Colors.green : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8)
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
             Icon(icon, color: active ? Colors.green : Colors.grey),
             const SizedBox(height: 2),
             Text(type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: active ? Colors.green : Colors.grey))
          ]),
        ),
      ),
    );
  }
  
  Widget _row(String label, num val) {
    if (val == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
         Text(label, style: const TextStyle(color: Colors.grey)),
         Text(_formatRupiah(val), style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}