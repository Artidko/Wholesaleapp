import 'package:flutter/material.dart';
import '../../services/order_service.dart';
import '../../models/order.dart';

class OrderViewPage extends StatefulWidget {
  final String orderId;
  const OrderViewPage({super.key, required this.orderId});

  @override
  State<OrderViewPage> createState() => _OrderViewPageState();
}

class _OrderViewPageState extends State<OrderViewPage> {
  OrderModel? order;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final data = await OrderService.instance.getOrder(widget.orderId);
      setState(() {
        order = data;
        loading = false;
      });
    } catch (e, st) {
      debugPrint('❌ Error loading order: $e\n$st');
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('คำสั่งซื้อ #${widget.orderId}')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _ErrorBox('โหลดคำสั่งซื้อไม่สำเร็จ:\n$error')
              : order == null
                  ? const _ErrorBox('ไม่พบคำสั่งซื้อ')
                  : _buildContent(order!),
    );
  }

  Widget _buildContent(OrderModel order) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('สถานะ: ${_statusToTh(order.status)}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('ที่อยู่จัดส่ง: ${order.addressText ?? '-'}'),
        Text('ชำระเงิน: ${order.paymentText ?? '-'}'),
        const Divider(height: 32),
        const Text('สินค้า', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (order.lines.isEmpty) const Text('ไม่มีรายการสินค้า'),
        ...order.lines.map((it) {
          final name = it.name.isNotEmpty ? it.name : '(ไม่ระบุชื่อสินค้า)';
          final qty = it.qty;
          final price = it.price;
          final lineTotal = it.lineTotal;

          return ListTile(
            leading: (it.imageUrl).isNotEmpty
                ? Image.network(
                    it.imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image_not_supported),
                  )
                : const Icon(Icons.image_not_supported),
            title: Text(name),
            subtitle: Text('x$qty • ฿${price.toStringAsFixed(0)}'),
            trailing: Text('฿${lineTotal.toStringAsFixed(0)}'),
          );
        }).toList(),
        const Divider(height: 32),
        _row('ยอดสินค้า', '฿${order.subTotal.toStringAsFixed(0)}'),
        _row('ค่าส่ง', '฿${order.shippingFee.toStringAsFixed(0)}'),
        const SizedBox(height: 8),
        _row('สุทธิ', '฿${order.grandTotal.toStringAsFixed(0)}', bold: true),
      ],
    );
  }

  String _statusToTh(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return 'รอดำเนินการ';
      case OrderStatus.paid:
        return 'ชำระแล้ว';
      case OrderStatus.preparing:
        return 'กำลังเตรียมสินค้า';
      case OrderStatus.delivering:
        return 'กำลังจัดส่ง';
      case OrderStatus.completed:
        return 'เสร็จสิ้น';
      case OrderStatus.cancelled:
        return 'ยกเลิก';
    }
  }

  Widget _row(String l, String r, {bool bold = false}) {
    final ts =
        TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(l, style: ts)),
          Text(r, style: ts),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('ย้อนกลับ'),
            ),
          ],
        ),
      ),
    );
  }
}
