import 'package:flutter/material.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  OrderModel? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final od = await OrderService.instance.getOrder(widget.orderId);
      setState(() {
        _order = od;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('รายละเอียดออเดอร์')),
        body: Center(child: Text('เกิดข้อผิดพลาด: $_error')),
      );
    }
    final o = _order!;
    return Scaffold(
      appBar: AppBar(title: Text('ออเดอร์ #${o.id.substring(0, 6)}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, size: 28),
              const SizedBox(width: 8),
              Text(
                'สถานะ: ${statusToString(o.status)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('สร้างเมื่อ: ${o.createdAt}'),
          const Divider(height: 32),
          const Text('สินค้าในคำสั่งซื้อ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...o.lines.map((l) => ListTile(
                leading: l.imageUrl.isNotEmpty
                    ? Image.network(l.imageUrl,
                        width: 48, height: 48, fit: BoxFit.cover)
                    : const Icon(Icons.image_not_supported),
                title: Text(l.name),
                subtitle: Text('จำนวน: ${l.qty}  •  ราคา/ชิ้น: ${l.price}'),
                trailing: Text('${l.lineTotal}'),
              )),
          const Divider(height: 32),
          _kv('ยอดรวมสินค้า', '${o.subTotal}'),
          _kv('ค่าส่ง', '${o.shippingFee}'),
          const SizedBox(height: 4),
          _kv('ยอดชำระทั้งหมด', '${o.grandTotal}', bold: true),
          const Divider(height: 32),
          const Text('ที่อยู่จัดส่ง',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(o.addressText.isNotEmpty ? o.addressText : '-'),
          const SizedBox(height: 16),
          const Text('วิธีชำระเงิน',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(o.paymentText.isNotEmpty ? o.paymentText : '-'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('กลับหน้าก่อนหน้า'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    final style = TextStyle(
        fontSize: 15, fontWeight: bold ? FontWeight.w700 : FontWeight.w400);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(k, style: style), Text(v, style: style)],
      ),
    );
  }
}
