import 'package:flutter/material.dart';
import '../../services/order_service.dart';
import '../../models/order.dart';
import 'order_view_page.dart'; // หน้าแสดงรายละเอียดคำสั่งซื้อ

class OrderSuccessPage extends StatelessWidget {
  final String orderId;
  const OrderSuccessPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ชำระเงินสำเร็จ')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 96),
              const SizedBox(height: 16),
              const Text('สร้างคำสั่งซื้อเรียบร้อย!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('รหัสคำสั่งซื้อ: $orderId'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => OrderViewPage(orderId: orderId),
                  ));
                },
                child: const Text('ดูรายละเอียดคำสั่งซื้อ'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('กลับหน้าเดิม'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
