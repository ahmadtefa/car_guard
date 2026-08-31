// lib/presentation/screens/stations/add_expense_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/expense.dart';
import '../../providers/item_provider.dart';
import '../../providers/station_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  final String stationId;
  const AddExpenseScreen({super.key, required this.stationId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategoryId;
  DateTime _expenseDate = DateTime.now();

  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _unitCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _addedByCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expenseDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر نوع المصروف')),
      );
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text) ?? 1;
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;

    final expense = Expense(
      id: IdGenerator.generate(),
      stationId: widget.stationId,
      expenseDate: _expenseDate,
      categoryId: _selectedCategoryId!,
      description: _descCtrl.text.trim(),
      quantityMilliunits: (qty * 1000).round(),
      unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
      unitPrice: Money.fromDouble(price),
      addedBy: _addedByCtrl.text.trim().isEmpty
          ? null
          : _addedByCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    final ok = await context.read<StationProvider>().addExpense(expense);
    if (mounted) {
      if (ok) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('حدث خطأ'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _descCtrl,
      _qtyCtrl,
      _unitCtrl,
      _priceCtrl,
      _addedByCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ItemProvider>().expenseCategories;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إضافة مصروف'),
          actions: [
            TextButton(
              onPressed: _save,
              child: const Text('حفظ',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Category
                DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'نوع المصروف *',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat.id,
                      child: Text(cat.nameAr),
                    );
                  }).toList(),
                  onChanged: (v) =>
                      setState(() => _selectedCategoryId = v),
                  validator: (v) => v == null ? 'اختر نوع المصروف' : null,
                ),
                const SizedBox(height: 12),

                // Date
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'التاريخ',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      '${_expenseDate.day}/${_expenseDate.month}/${_expenseDate.year}',
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الوصف *',
                    prefixIcon: Icon(Icons.description),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'الوصف مطلوب' : null,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qtyCtrl,
                        decoration: const InputDecoration(labelText: 'الكمية'),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitCtrl,
                        decoration: const InputDecoration(labelText: 'الوحدة'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'السعر (ج.م) *',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'السعر مطلوب';
                    if (double.tryParse(v.replaceAll(',', '')) == null) {
                      return 'رقم غير صالح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _addedByCtrl,
                  decoration: const InputDecoration(
                    labelText: 'أضافه',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('إضافة المصروف'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
