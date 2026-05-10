import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart';

class OrderTimerWidget extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderTimerWidget({super.key, required this.order});

  @override
  State<OrderTimerWidget> createState() => _OrderTimerWidgetState();
}

class _OrderTimerWidgetState extends State<OrderTimerWidget> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isOverdue = false;
  bool _hasTarget = false;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr == '-' || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr).toLocal(); // Standard ISO
    } catch (e) {
      try {
        return DateFormat('dd/MM/yyyy HH:mm').parse(dateStr); 
      } catch (e2) {
        try {
           return DateFormat('d MMM yyyy HH:mm').parse(dateStr);
        } catch(e3) {
            return null;
        }
      }
    }
  }

  void _updateTime() {
    DateTime? targetTime;
    
    // 1. Prioritaskan global target dari kasir
    if (widget.order['completed_target_at'] != null) {
        targetTime = _parseDate(widget.order['completed_target_at']?.toString());
    }
    
    // 2. Fallback ke Jadwal jika bukan Sekarang
    if (targetTime == null && widget.order['delivery_scheduled_at'] != null) {
        final sched = widget.order['delivery_scheduled_at'].toString();
        if (sched.toLowerCase() != 'sekarang' && sched != '-') {
            targetTime = _parseDate(sched);
        }
    }

    // 3. Fallback cerdas: +15 menit dari event sebelumnya kalau null
    if (targetTime == null) {
       final status = (widget.order['status'] as String? ?? '').toUpperCase();
       if (status == 'DRAFT') {
           final baseDate = _parseDate(widget.order['created_at']?.toString());
           if (baseDate != null) targetTime = baseDate.add(const Duration(minutes: 45)); // Dummy fallback (Asumsi lama)
       } else if (status == 'READY') {
           final baseDate = _parseDate(widget.order['ready_time']?.toString());
           if (baseDate != null) targetTime = baseDate.add(const Duration(minutes: 15));
       } else if (status == 'ON_DELIVERY') {
           final baseDate = _parseDate(widget.order['delivery_time']?.toString());
           if (baseDate != null) targetTime = baseDate.add(const Duration(minutes: 15));
       }
    }

    if (targetTime == null) {
        if (mounted) setState(() { _hasTarget = false; });
        return;
    }

    final now = DateTime.now();
    final result = targetTime.difference(now);

    if (mounted) {
      setState(() {
        _hasTarget = true;
        if (result.isNegative) {
            _remaining = Duration.zero; 
            _isOverdue = true;
        } else {
            _remaining = result;
            _isOverdue = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide if no target time or status irrelevant
    if (!_hasTarget) return const SizedBox.shrink();

    final status = (widget.order['status'] as String? ?? '').toUpperCase();
    if (!['DRAFT', 'PREPARED', 'READY', 'ON_DELIVERY'].contains(status)) {
        return const SizedBox.shrink();
    }

    String timeStr;
    if (_remaining.inHours > 0) {
       final h = _remaining.inHours.toString().padLeft(2, '0');
       final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
       final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
       timeStr = "$h:$m:$s";
    } else {
       final m = _remaining.inMinutes.toString().padLeft(2, '0');
       final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
       timeStr = "$m:$s";
    }
    
    Color bgColor;
    Color textColor;
    
    if (_isOverdue) {
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        timeStr = "Waktu Habis";
    } else {
       bgColor = Colors.blue.shade50;
       textColor = Colors.blue.shade800;
       if (status == 'ON_DELIVERY') {
           textColor = Colors.purple.shade800;
           bgColor = Colors.purple.shade50;
       }
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _isOverdue ? Colors.red.withOpacity(0.5) : Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: textColor),
          const SizedBox(width: 4),
          if (!_isOverdue) Text("Sisa: ", style: TextStyle(fontSize: 10, color: textColor)),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.bold, 
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
