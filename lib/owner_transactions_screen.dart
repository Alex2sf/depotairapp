import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

class OwnerTransactionsScreen extends StatefulWidget {
  const OwnerTransactionsScreen({super.key});

  @override
  State<OwnerTransactionsScreen> createState() => _OwnerTransactionsScreenState();
}

class _OwnerTransactionsScreenState extends State<OwnerTransactionsScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _lastPage = 1;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _currentPage < _lastPage) {
      _loadMoreTransactions();
    }
  }

  Future<void> _fetchTransactions({bool reset = true}) async {
    if (reset) {
      _currentPage = 1;
      if (mounted) setState(() { _isLoading = true; _transactions = []; });
    }

    String startApi = DateFormat('yyyy-MM-dd').format(_startDate);
    String endApi = DateFormat('yyyy-MM-dd').format(_endDate);

    final result = await _apiService.getOwnerTransactions(startDate: startApi, endDate: endApi, page: _currentPage);

    if (mounted) {
      setState(() {
         if (result != null) {
            _transactions.addAll(result['data'] ?? []);
            _lastPage = result['pagination']?['last_page'] ?? _currentPage;
         }
         _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_currentPage < _lastPage) {
      _currentPage++;
      String startApi = DateFormat('yyyy-MM-dd').format(_startDate);
      String endApi = DateFormat('yyyy-MM-dd').format(_endDate);
      final result = await _apiService.getOwnerTransactions(startDate: startApi, endDate: endApi, page: _currentPage);
      
      if (mounted && result != null) {
        setState(() => _transactions.addAll(result['data'] ?? []));
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) => Theme(
          data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: Colors.blue.shade900)),
          child: child!
      )
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchTransactions(reset: true);
    }
  }

  String _formatCurrency(num amount) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Riwayat Transaksi", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
           // FILTER DATE
           Container(
             padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
             decoration: BoxDecoration(
               gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade600], begin: Alignment.topCenter, end: Alignment.bottomCenter),
               borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
               boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]
             ),
             child: Center(
               child: GestureDetector(
                 onTap: _selectDateRange,
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                   decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(25)),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                        const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "${_formatDate(_startDate)} - ${_formatDate(_endDate)}", 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18)
                     ],
                   ),
                 ),
               ),
             ),
           ),

           // LIST
           Expanded(
             child: RefreshIndicator(
               onRefresh: () => _fetchTransactions(reset: true),
               child: _isLoading && _transactions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                      ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history, size: 60, color: Colors.grey), SizedBox(height: 10), Text("Tidak ada transaksi", style: TextStyle(color: Colors.grey))]))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _transactions.length + (_currentPage < _lastPage ? 1 : 0),
                          itemBuilder: (context, index) {
                             if (index == _transactions.length) return const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()));
                             return _buildTransactionCard(_transactions[index]);
                          },
                        ),
             ),
           )
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> item) {
     final bool isExpense = item['tipe'] == 'Pengeluaran';
     final Color color = isExpense ? Colors.red.shade700 : Colors.green.shade700;
     final IconData icon = isExpense ? Icons.arrow_upward : Icons.arrow_downward;

     return Container(
       margin: const EdgeInsets.only(bottom: 12),
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(12),
         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0,2))],
         border: Border(left: BorderSide(color: color, width: 4))
       ),
       child: ListTile(
         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
         leading: Container(
           padding: const EdgeInsets.all(8),
           decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
           child: Icon(icon, color: color, size: 20),
         ),
         title: Text(item['keterangan'] ?? 'Transaksi', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
         subtitle: Padding(
           padding: const EdgeInsets.only(top: 4.0),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('${item['waktu']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
               Text('Oleh: ${item['oleh']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
             ],
           ),
         ),
         trailing: Text(
           _formatCurrency(item['jumlah'] ?? 0),
           style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15),
         ),
       ),
     );
  }
}