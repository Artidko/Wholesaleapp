// lib/pages/admin/admin_finance_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  final _ranges = const ['วันนี้', '7 วัน', '30 วัน', 'YTD'];
  String _selected = '30 วัน';

  ({DateTime start, DateTime end}) _currentRange() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (_selected) {
      case 'วันนี้':
        return (start: DateTime(now.year, now.month, now.day), end: end);
      case '7 วัน':
        final s = now.subtract(const Duration(days: 6));
        return (start: DateTime(s.year, s.month, s.day), end: end);
      case '30 วัน':
        final s = now.subtract(const Duration(days: 29));
        return (start: DateTime(s.year, s.month, s.day), end: end);
      case 'YTD':
      default:
        return (start: DateTime(now.year, 1, 1), end: end);
    }
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  String _thaiType(FinanceType t) =>
      t == FinanceType.income ? 'รายรับ' : 'รายจ่าย';

  Icon _iconFor(FinanceType t) => Icon(
        t == FinanceType.income ? Icons.trending_up : Icons.trending_down,
        color: t == FinanceType.income ? Colors.green : Colors.red,
      );

  // ---------- Small UI builders ----------
  InputDecoration _fieldDec({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.black54),
      filled: true,
      fillColor: Colors.black.withOpacity(.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), // กล่องโค้ง 10px
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            BorderSide(color: Theme.of(context).colorScheme.primary, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  ButtonStyle _capsulePrimary(BuildContext ctx) {
    final primary = Theme.of(ctx).colorScheme.primary;
    return FilledButton.styleFrom(
      backgroundColor: primary.withOpacity(.12),
      foregroundColor: primary.withOpacity(.95),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
      elevation: 0,
    );
  }

  Future<void> _addOrEdit({FinanceEntry? editing}) async {
    final isEditing = editing != null;

    final typeVN =
        ValueNotifier<FinanceType>(editing?.type ?? FinanceType.expense);
    final amountCtrl = TextEditingController(
        text: isEditing ? editing.amount.toString() : '');
    final noteCtrl =
        TextEditingController(text: isEditing ? editing.note : '');
    final categoryCtrl = TextEditingController(
      text: isEditing
          ? editing.category
          : (typeVN.value == FinanceType.expense
              ? 'General Expense'
              : 'Manual Income'),
    );
    DateTime picked = isEditing ? editing.date : DateTime.now();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final primary = theme.colorScheme.primary;

        Widget typeButton(FinanceType me, String label) {
          final isSel = typeVN.value == me;
          return OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: const Size(0, 40),
              side: BorderSide(
                color: isSel ? primary.withOpacity(.55) : Colors.grey.shade300,
                width: isSel ? 1.5 : 1,
              ),
              backgroundColor: isSel ? primary.withOpacity(.06) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              foregroundColor: Colors.black87,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              typeVN.value = me;
              if (categoryCtrl.text.trim().isEmpty ||
                  (me == FinanceType.expense &&
                      categoryCtrl.text == 'Manual Income') ||
                  (me == FinanceType.income &&
                      categoryCtrl.text == 'General Expense')) {
                categoryCtrl.text = me == FinanceType.expense
                    ? 'General Expense'
                    : 'Manual Income';
              }
            },
            child: Text(label),
          );
        }

        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          backgroundColor: theme.colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: StatefulBuilder(builder: (ctx, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // หัวข้อ + ไอคอนเล็ก
                  Row(
                    children: [
                      Icon(Icons.receipt_long,
                          size: 18,
                          color: theme.colorScheme.onSurface.withOpacity(.7)),
                      const SizedBox(width: 8),
                      Text(isEditing ? 'แก้ไขรายการ' : 'เพิ่มรายการ',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ปุ่มสลับประเภท
                  ValueListenableBuilder<FinanceType>(
                    valueListenable: typeVN,
                    builder: (_, __, ___) => Row(
                      children: [
                        typeButton(FinanceType.expense, 'รายจ่าย'),
                        const SizedBox(width: 8),
                        typeButton(FinanceType.income, 'รายรับ'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _fieldDec(
                      label: 'จำนวนเงิน',
                      icon: Icons.payments,
                      hint: 'เช่น 500',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: categoryCtrl,
                    decoration: _fieldDec(
                      label: 'หมวดหมู่',
                      icon: Icons.category_outlined,
                      hint: 'เช่น ค่าขนส่ง / เงินโอนเข้า',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    decoration: _fieldDec(
                      label: 'รายละเอียด (เช่น ค่าขนส่ง / รับชำระ ...)',
                      icon: Icons.note_alt_outlined,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    elevation: 1, // เงาบาง ๆ ให้ดูมีเลเยอร์
                    shadowColor: Colors.black12,
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
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
                  ),
                  const SizedBox(height: 14),
                  // ปุ่มล่าง: ยกเลิก / บันทึก (แคปซูล primary จาง ๆ)
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('ยกเลิก'),
                      ),
                      const Spacer(),
                      FilledButton(
                        style: _capsulePrimary(ctx),
                        onPressed: () async {
                          final amt = double.tryParse(amountCtrl.text.trim());
                          if (amt == null || amt <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('กรุณากรอกจำนวนเงินให้ถูกต้อง')),
                            );
                            return;
                          }

                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('กรุณาเข้าสู่ระบบก่อนบันทึก')),
                            );
                            return;
                          }

                          final t = typeVN.value;
                          final entry = FinanceEntry(
                            id: isEditing ? editing.id : '',
                            type: t,
                            amount: amt,
                            orderId: isEditing ? editing.orderId : null,
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
                              await FinanceService.instance
                                  .updateExpense(entry);
                            } else {
                              if (t == FinanceType.expense) {
                                await FinanceService.instance.addExpense(
                                  amount: entry.amount,
                                  category: entry.category,
                                  note: entry.note,
                                  date: entry.date,
                                );
                              } else {
                                // รายรับแบบ manual -> แนบ createdBy ให้ผ่าน rules
                                final ref = FirebaseFirestore.instance
                                    .collection('finance_entries')
                                    .doc();
                                final map = entry.toMap();
                                map['id'] = ref.id;
                                map['createdAt'] = FieldValue.serverTimestamp();
                                map['createdBy'] = uid;
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
                        child: Text(isEditing ? 'อัปเดต' : 'บันทึก'),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> _delete(FinanceEntry e) async {
    await FinanceService.instance.deleteEntry(e.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('ลบรายการแล้ว')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final headerStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final range = _currentRange();

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(Icons.account_balance,
              size: 18, color: theme.colorScheme.onSurface.withOpacity(.7)),
          const SizedBox(width: 8),
          Text('บันทึกรายรับ–รายจ่าย',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );

    final rangeBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        elevation: 1,
        shadowColor: Colors.black12,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: _ranges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final r = _ranges[i];
              final sel = r == _selected;
              return OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                  side: BorderSide(
                    color:
                        sel ? primary.withOpacity(.55) : Colors.grey.shade300,
                    width: sel ? 1.5 : 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: sel ? primary.withOpacity(.06) : null,
                  foregroundColor: Colors.black87,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () => setState(() => _selected = r),
                child: Text(r),
              );
            },
          ),
        ),
      ),
    );

    return Scaffold(
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
              header,
              rangeBar,
              // Summary cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.trending_up,
                                color: Colors.green),
                          ),
                          title: const Text('รายรับ'),
                          subtitle: Text(_fmtMoney.format(income),
                              style: headerStyle),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.trending_down,
                                color: Colors.red),
                          ),
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
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_balance_wallet),
                    ),
                    title: const Text('สุทธิ'),
                    subtitle: const Text('รายรับ - รายจ่าย'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _fmtMoney.format(net),
                        style: TextStyle(
                          color: primary.withOpacity(.85),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Divider(height: 16),
              ),
              // List
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final t = items[i];
                        final isIncome = t.type == FinanceType.income;
                        final tone = isIncome ? Colors.green : Colors.red;

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
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: tone.withOpacity(.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _iconFor(t.type),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _thaiType(t.type),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: primary.withOpacity(.06),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _fmtMoney.format(t.amount),
                                      style: TextStyle(
                                        color: primary.withOpacity(.85),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${t.category.isEmpty ? '-' : t.category} • '
                                  '${t.note.isEmpty ? '-' : t.note} • '
                                  '${_fmtDate.format(t.date)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
