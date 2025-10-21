import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ใช้เฉพาะปุ่ม refresh link (optional)

class PaymentSlipCard extends StatelessWidget {
  final String orderId;
  final bool enableRefreshSignedUrl; // ตั้ง false ได้ถ้าใช้ public URL

  const PaymentSlipCard({
    super.key,
    required this.orderId,
    this.enableRefreshSignedUrl = false,
  });

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

    return Card(
      margin: const EdgeInsets.all(12),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _tile(
              context,
              title: 'สลิปการโอน',
              child: _error('โหลดข้อมูลผิดพลาด: ${snap.error}'),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return _tile(
              context,
              title: 'สลิปการโอน',
              child: const _loading(),
            );
          }

          final data = snap.data!.data()!;
          final pay = (data['payment'] ?? {}) as Map<String, dynamic>;
          final status = (pay['reviewStatus'] ?? '—') as String;
          final slipUrl = (pay['slipUrl'] ?? '') as String;
          final storage = (pay['storage'] ?? '') as String; // 'supabase' | ''
          final bucket = (pay['bucket'] ?? '') as String?;
          final path = (pay['path'] ?? '') as String?;

          final chipColor = switch (status) {
            'pending' => Colors.orange,
            'approved' => Colors.green,
            'rejected' => Colors.red,
            _ => Colors.grey,
          };

          return _tile(
            context,
            title: 'สลิปการโอน',
            trailing: Chip(
              label: Text(status),
              backgroundColor: chipColor.withOpacity(0.15),
              side: BorderSide(color: chipColor),
              labelStyle: TextStyle(color: chipColor.shade700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (slipUrl.isEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('ยังไม่มีสลิปแนบจากลูกค้า'),
                  const SizedBox(height: 12),
                ] else ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: InkWell(
                        onTap: () => _showFullScreen(context, slipUrl),
                        child: Image.network(
                          slipUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imageError(context),
                          loadingBuilder: (ctx, child, prog) {
                            if (prog == null) return child;
                            final v = prog.expectedTotalBytes != null
                                ? (prog.cumulativeBytesLoaded /
                                        prog.expectedTotalBytes!)
                                    .clamp(0, 1)
                                : null;
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                const ColoredBox(color: Color(0xfff2f2f2)),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(),
                                      if (v != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                            '${(v * 100).toStringAsFixed(0)}%'),
                                      ]
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('เปิดเต็มจอ'),
                        onPressed: () => _showFullScreen(context, slipUrl),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.link),
                        label: const Text('คัดลอกลิงก์'),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: slipUrl));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('คัดลอกลิงก์แล้ว')),
                            );
                          }
                        },
                      ),
                      if (enableRefreshSignedUrl &&
                          storage == 'supabase' &&
                          (bucket?.isNotEmpty ?? false) &&
                          (path?.isNotEmpty ?? false)) ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('รีเฟรชลิงก์'),
                          onPressed: () async {
                            final supabase = Supabase.instance.client;
                            final newUrl = await supabase.storage
                                .from(bucket!)
                                .createSignedUrl(
                                    path!, 60 * 60 * 24 * 7); // อายุ 7 วัน
                            await docRef.set({
                              'payment': {'slipUrl': newUrl}
                            }, SetOptions(merge: true));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('อัปเดตลิงก์ใหม่แล้ว')),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                _caption(data),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _imageError(BuildContext ctx) => Container(
        color: const Color(0xfff2f2f2),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined,
                size: 28, color: Colors.grey),
            const SizedBox(height: 6),
            Text('โหลดรูปไม่สำเร็จ', style: Theme.of(ctx).textTheme.bodySmall),
          ],
        ),
      );

  static void _showFullScreen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  static Widget _caption(Map<String, dynamic> orderData) {
    final pay = (orderData['payment'] ?? {}) as Map<String, dynamic>;
    final by = (pay['submittedBy'] ?? '-') as String;
    final method = (pay['method'] ?? '-') as String;
    return Text(
      'วิธีชำระ: $method • ผู้ส่งสลิป: $by',
      style: const TextStyle(fontSize: 12, color: Colors.black54),
    );
  }

  Widget _tile(BuildContext ctx,
      {required String title, Widget? trailing, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            const Spacer(),
            if (trailing != null) trailing,
          ]),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _loading extends StatelessWidget {
  const _loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('กำลังโหลด…'),
        ],
      ),
    );
  }
}

Widget _error(String msg) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(msg, style: const TextStyle(color: Colors.red)),
    );
