// lib/pages/admin/admin_finance_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/finance_service.dart';
import '../../../models/finance_entry.dart'; // FinanceEntry, FinanceType

class AdminFinanceTab extends StatefulWidget {
  const AdminFinanceTab({super.key});

  @override
  State<AdminFinanceTab> createState() => _AdminFinanceTabState();
}

class _AdminFinanceTabState extends State<AdminFinanceTab> {
  final _fmtDate = DateFormat('dd MMM yyyy');
  final _fmtMoney =
      NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

  // range selector
  final _ranges = const ['วันนี้', '7 วัน', '30 วัน', 'YTD'];
  String _selected = '30 วัน';

  // คำนวณช่วงวันจากตัวเลือก
  ({DateTime start, DateTime end}) _currentRange() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (_selected) {
      case 'วันนี้':
        return (
          start: DateTime(now.year, now.month, now.day, 0, 0, 0),
          end: end
        );
      case '7 วัน':
        final s = now.subtract(const Duration(days: 6));
        return (start: DateTime(s.year, s.month, s.day, 0, 0, 0), end: end);
      case '30 วัน':
        final s = now.subtract(const Duration(days: 29));
        return (start: DateTime(s.year, s.month, s.day, 0, 0, 0), end: end);
      case 'YTD':
      default:
        return (start: DateTime(now.year, 1, 1, 0, 0, 0), end: end);
    }
  }

  // ---------- helpers ----------
  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _thaiType(FinanceType t) =>
      t == FinanceType.income ? 'รายรับ' : 'รายจ่าย';

  Icon _iconFor(FinanceType t) => Icon(
        t == FinanceType.income ? Icons.arrow_downward : Icons.arrow_upward,
        color: t == FinanceType.income ? Colors.green : Colors.red,
      );

  // ---------- CRUD ----------
  Future<void> _addOrEdit({FinanceEntry? editing}) async {
    final isEditing = editing != null;

    final typeVN = ValueNotifier<FinanceType>(
        editing?.type ?? FinanceType.expense); // default รายจ่าย
    final amountCtrl = TextEditingController(
        text: isEditing ? editing!.amount.toString() : '');
    final noteCtrl =
        TextEditingController(text: isEditing ? editing!.note : '');
    final categoryCtrl = TextEditingController(
      text: isEditing
          ? editing!.category
          : (typeVN.value == FinanceType.expense
              ? 'General Expense'
              : 'Manual Income'),
    );
    DateTime picked = isEditing ? editing!.date : DateTime.now();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: Text(isEditing ? 'แก้ไขรายการ' : 'เพิ่มรายการ'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<FinanceType>(
                    valueListenable: typeVN,
                    builder: (_, t, __) => Row(
                      children: [
                        ChoiceChip(
                          label: const Text('รายจ่าย'),
                          selected: t == FinanceType.expense,
                          onSelected: (_) {
                            typeVN.value = FinanceType.expense;
                            if (categoryCtrl.text.trim().isEmpty ||
                                categoryCtrl.text == 'Manual Income') {
                              categoryCtrl.text = 'General Expense';
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('รายรับ'),
                          selected: t == FinanceType.income,
                          onSelected: (_) {
                            typeVN.value = FinanceType.income;
                            if (categoryCtrl.text.trim().isEmpty ||
                                categoryCtrl.text == 'General Expense') {
                              categoryCtrl.text = 'Manual Income';
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'จำนวนเงิน',
                      prefixIcon: Icon(Icons.payments),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'หมวดหมู่',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'รายละเอียด (เช่น ค่าขนส่ง / รับชำระ ...)',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('วันที่รายการ'),
                    subtitle: Text(_fmtDate.format(picked)),
                    trailing: TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: picked,
                        );
                        if (d != null) setStateDialog(() => picked = d);
                      },
                      child: const Text('เลือกวันที่'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก')),
              FilledButton(
                child: Text(isEditing ? 'อัปเดต' : 'บันทึก'),
                onPressed: () async {
                  final amt = double.tryParse(amountCtrl.text.trim());
                  if (amt == null || amt <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('กรุณากรอกจำนวนเงินให้ถูกต้อง')),
                    );
                    return;
                  }

                  final t = typeVN.value;
                  final entry = FinanceEntry(
                    id: isEditing ? editing!.id : '', // จะกำหนดใหม่ถ้าเป็นเพิ่ม
                    type: t,
                    amount: amt,
                    orderId: isEditing ? editing!.orderId : null,
                    category: categoryCtrl.text.trim().isEmpty
                        ? (t == FinanceType.expense
                            ? 'General Expense'
                            : 'Manual Income')
                        : categoryCtrl.text.trim(),
                    note: noteCtrl.text.trim(),
                    date: _dayOnly(picked),
                    createdAt: DateTime.now(),
                  );

                  try {
                    if (isEditing) {
                      await FinanceService.instance.updateExpense(entry);
                    } else {
                      if (t == FinanceType.expense) {
                        await FinanceService.instance.addExpense(
                          amount: entry.amount,
                          category: entry.category,
                          note: entry.note,
                          date: entry.date,
                        );
                      } else {
                        // รายรับแบบแมนนวล: เขียนตรงเข้า collection ให้รูปแบบตรง FinanceEntry
                        final ref = FirebaseFirestore.instance
                            .collection('finance_entries')
                            .doc();

                        // แทน copyWith(): ทำ map แล้ว override id/createdAt
                        final map = entry.toMap();
                        map['id'] = ref.id;
                        map['createdAt'] = FieldValue.serverTimestamp();

                        await ref.set(map);
                      }
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(FinanceEntry e) async {
    await FinanceService.instance.deleteEntry(e.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ลบรายการแล้ว')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w700);

    final range = _currentRange();

    return Scaffold(
      appBar: AppBar(
        title: const Text('บันทึกรายรับ–รายจ่าย (Firestore)'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selected,
            onSelected: (v) => setState(() => _selected = v),
            itemBuilder: (_) => _ranges
                .map((e) => PopupMenuItem(value: e, child: Text(e)))
                .toList(),
            icon: const Icon(Icons.filter_alt),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มรายการ'),
      ),
      body: StreamBuilder<({double income, double expense})>(
        stream: FinanceService.instance.watchSummary(
          start: range.start,
          end: range.end,
        ),
        builder: (context, sumSnap) {
          final income = sumSnap.data?.income ?? 0;
          final expense = sumSnap.data?.expense ?? 0;
          final net = income - expense;

          return Column(
            children: [
              const SizedBox(height: 8),
              // cards summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.trending_up,
                              color: Colors.green),
                          title: const Text('รายรับ'),
                          subtitle: Text(_fmtMoney.format(income),
                              style: headerStyle),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.trending_down,
                              color: Colors.red),
                          title: const Text('รายจ่าย'),
                          subtitle: Text(_fmtMoney.format(expense),
                              style: headerStyle),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: const Text('สุทธิ'),
                    subtitle: const Text('รายรับ - รายจ่าย'),
                    trailing: Text(
                      _fmtMoney.format(net),
                      style: TextStyle(
                        color: net >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 0),

              // entries list
              Expanded(
                child: StreamBuilder<List<FinanceEntry>>(
                  stream: FinanceService.instance.watchEntries(
                    start: range.start,
                    end: range.end,
                  ),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                          child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
                    }
                    final items = snap.data ?? [];
                    if (items.isEmpty) {
                      return const Center(child: Text('ยังไม่มีรายการ'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final t = items[i];
                        return Dismissible(
                          key: ValueKey(t.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            color: Colors.red.shade400,
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => _delete(t),
                          child: Card(
                            child: ListTile(
                              leading: _iconFor(t.type),
                              title: Text(
                                '${_thaiType(t.type)} — ${_fmtMoney.format(t.amount)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${t.category.isEmpty ? '-' : t.category} • '
                                '${t.note.isEmpty ? '-' : t.note} • '
                                '${_fmtDate.format(t.date)}',
                              ),
                              onTap: () => _addOrEdit(editing: t),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') _addOrEdit(editing: t);
                                  if (v == 'delete') _delete(t);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'edit',
                                      child: Text('แก้ไขรายการ')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('ลบรายการ')),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
