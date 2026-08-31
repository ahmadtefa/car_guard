// lib/presentation/screens/stations/add_station_item_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/catalog_item.dart';
import '../../../domain/entities/station_item.dart';
import '../../providers/item_provider.dart';
import '../../providers/station_provider.dart';

class AddStationItemScreen extends StatefulWidget {
  final String stationId;
  const AddStationItemScreen({super.key, required this.stationId});

  @override
  State<AddStationItemScreen> createState() => _AddStationItemScreenState();
}

class _AddStationItemScreenState extends State<AddStationItemScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isCustom = false;
  CatalogItem? _selectedItem;

  final _descCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  void _onItemSelected(CatalogItem item) {
    setState(() {
      _selectedItem = item;
      _descCtrl.text = item.name;
      _brandCtrl.text = item.brand ?? '';
      _modelCtrl.text = item.model ?? '';
      _unitCtrl.text = item.unit ?? '';
      _priceCtrl.text = (item.unitPrice.millimes / 1000).toString();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final quantity = double.tryParse(_qtyCtrl.text) ?? 1;
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;
    final discount = double.tryParse(_discountCtrl.text) ?? 0;
    final tax = double.tryParse(_taxCtrl.text) ?? 0;

    final item = StationItem(
      id: IdGenerator.generate(),
      stationId: widget.stationId,
      itemId: _selectedItem?.id,
      description: _descCtrl.text.trim(),
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
      quantityMilliunits: (quantity * 1000).round(),
      unitPriceSnapshot: Money.fromDouble(price),
      discountPercentageCents: (discount * 100).round(),
      taxPercentageCents: (tax * 100).round(),
      notes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    final ok =
        await context.read<StationProvider>().addStationItem(item);
    if (mounted) {
      if (ok) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('حدث خطأ'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _descCtrl,
      _brandCtrl,
      _modelCtrl,
      _unitCtrl,
      _qtyCtrl,
      _priceCtrl,
      _discountCtrl,
      _taxCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إضافة بند'),
          actions: [
            TextButton(
              onPressed: _save,
              child:
                  const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle: from catalog or custom
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: false,
                        label: Text('من الكتالوج'),
                        icon: Icon(Icons.inventory_2)),
                    ButtonSegment(
                        value: true,
                        label: Text('بند مخصص'),
                        icon: Icon(Icons.add_box)),
                  ],
                  selected: {_isCustom},
                  onSelectionChanged: (v) {
                    setState(() {
                      _isCustom = v.first;
                      _selectedItem = null;
                      _descCtrl.clear();
                      _brandCtrl.clear();
                      _modelCtrl.clear();
                      _unitCtrl.clear();
                      _priceCtrl.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Catalog picker
                if (!_isCustom) ...[
                  const Text('اختر من الكتالوج:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<CatalogItem>(
                    initialValue: _selectedItem,
                    decoration: const InputDecoration(
                      labelText: 'اختر بنداً',
                      prefixIcon: Icon(Icons.inventory_2),
                    ),
                    items: itemProvider.items.map((item) {
                      return DropdownMenuItem(
                        value: item,
                        child: Text(
                          '${item.name} - ${(item.unitPrice.millimes / 1000).toStringAsFixed(0)} ج.م',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) _onItemSelected(v);
                    },
                    validator: (v) =>
                        !_isCustom && v == null ? 'اختر بنداً' : null,
                  ),
                  const SizedBox(height: 12),
                ],

                // Description
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
                        controller: _brandCtrl,
                        decoration:
                            const InputDecoration(labelText: 'الماركة'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _modelCtrl,
                        decoration:
                            const InputDecoration(labelText: 'الموديل'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qtyCtrl,
                        decoration:
                            const InputDecoration(labelText: 'الكمية *'),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'مطلوب';
                          if (double.tryParse(v) == null) return 'رقم غير صالح';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitCtrl,
                        decoration:
                            const InputDecoration(labelText: 'الوحدة'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'سعر الوحدة (ج.م) *',
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
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _discountCtrl,
                        decoration: const InputDecoration(
                            labelText: 'خصم %',
                            hintText: '0'),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _taxCtrl,
                        decoration: const InputDecoration(
                            labelText: 'ضريبة %',
                            hintText: '0'),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Live total preview
                _TotalPreview(
                  qty: double.tryParse(_qtyCtrl.text) ?? 1,
                  price: double.tryParse(
                          _priceCtrl.text.replaceAll(',', '')) ??
                      0,
                  discount:
                      double.tryParse(_discountCtrl.text) ?? 0,
                  tax: double.tryParse(_taxCtrl.text) ?? 0,
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
                    label: const Text('إضافة البند'),
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

class _TotalPreview extends StatelessWidget {
  final double qty;
  final double price;
  final double discount;
  final double tax;
  const _TotalPreview({
    required this.qty,
    required this.price,
    required this.discount,
    required this.tax,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = qty * price;
    final discountAmt = subtotal * (discount / 100);
    final afterDiscount = subtotal - discountAmt;
    final taxAmt = afterDiscount * (tax / 100);
    final total = afterDiscount + taxAmt;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المجموع الفرعي:',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              Text(subtotal.toStringAsFixed(2),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            ],
          ),
          if (discount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الخصم:',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                Text('-${discountAmt.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: Colors.red)),
              ],
            ),
          if (tax > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الضريبة:',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                Text('+${taxAmt.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: Colors.orange)),
              ],
            ),
          const Divider(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي:',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              Text(
                '${total.toStringAsFixed(2)} ج.م',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
