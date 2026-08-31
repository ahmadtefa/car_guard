// lib/presentation/screens/stations/add_edit_station_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/station.dart';
import '../../providers/customer_provider.dart';
import '../../providers/station_provider.dart';

class AddEditStationScreen extends StatefulWidget {
  final Station? station; // null = add, not null = edit

  const AddEditStationScreen({super.key, this.station});

  @override
  State<AddEditStationScreen> createState() => _AddEditStationScreenState();
}

class _AddEditStationScreenState extends State<AddEditStationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _stationNumberCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _latitudeCtrl;
  late final TextEditingController _longitudeCtrl;
  late final TextEditingController _landAreaCtrl;
  late final TextEditingController _roofAreaCtrl;
  late final TextEditingController _availableAreaCtrl;
  late final TextEditingController _projectTypeCtrl;
  late final TextEditingController _requiredCapacityCtrl;
  late final TextEditingController _totalPanelsCapacityCtrl;
  late final TextEditingController _responsiblePersonCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _sellingPriceCtrl;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _taxCtrl;

  String _selectedStatus = 'study';
  String? _selectedCustomerId;

  bool get _isEditing => widget.station != null;

  @override
  void initState() {
    super.initState();
    final s = widget.station;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _stationNumberCtrl = TextEditingController(text: s?.stationNumber ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _latitudeCtrl =
        TextEditingController(text: s?.latitude?.toString() ?? '');
    _longitudeCtrl =
        TextEditingController(text: s?.longitude?.toString() ?? '');
    _landAreaCtrl = TextEditingController(text: s?.landArea?.toString() ?? '');
    _roofAreaCtrl = TextEditingController(text: s?.roofArea?.toString() ?? '');
    _availableAreaCtrl =
        TextEditingController(text: s?.availableArea?.toString() ?? '');
    _projectTypeCtrl = TextEditingController(text: s?.projectType ?? '');
    _requiredCapacityCtrl =
        TextEditingController(text: s?.requiredCapacityKwp?.toString() ?? '');
    _totalPanelsCapacityCtrl = TextEditingController(
        text: s?.totalPanelsCapacityKwp?.toString() ?? '');
    _responsiblePersonCtrl =
        TextEditingController(text: s?.responsiblePerson ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
    _sellingPriceCtrl = TextEditingController(
        text: s != null ? (s.sellingPrice.millimes / 1000).toString() : '');
    _discountCtrl = TextEditingController(
        text: s != null ? (s.discount.millimes / 1000).toString() : '');
    _taxCtrl = TextEditingController(
        text: s != null ? s.taxPercentage.toString() : '0');
    _selectedStatus = s?.status ?? 'study';
    _selectedCustomerId = s?.customerId;

    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final num =
            await context.read<StationProvider>().generateStationNumber();
        _stationNumberCtrl.text = num;
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _stationNumberCtrl,
      _addressCtrl,
      _latitudeCtrl,
      _longitudeCtrl,
      _landAreaCtrl,
      _roofAreaCtrl,
      _availableAreaCtrl,
      _projectTypeCtrl,
      _requiredCapacityCtrl,
      _totalPanelsCapacityCtrl,
      _responsiblePersonCtrl,
      _notesCtrl,
      _sellingPriceCtrl,
      _discountCtrl,
      _taxCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final station = Station(
      id: widget.station?.id ?? IdGenerator.generate(),
      stationNumber: _stationNumberCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      customerId: _selectedCustomerId,
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      latitude: double.tryParse(_latitudeCtrl.text),
      longitude: double.tryParse(_longitudeCtrl.text),
      landArea: double.tryParse(_landAreaCtrl.text),
      roofArea: double.tryParse(_roofAreaCtrl.text),
      availableArea: double.tryParse(_availableAreaCtrl.text),
      projectType: _projectTypeCtrl.text.trim().isEmpty ? null : _projectTypeCtrl.text.trim(),
      requiredCapacityKwp: double.tryParse(_requiredCapacityCtrl.text),
      totalPanelsCapacityKwp: double.tryParse(_totalPanelsCapacityCtrl.text),
      status: _selectedStatus,
      responsiblePerson: _responsiblePersonCtrl.text.trim().isEmpty
          ? null
          : _responsiblePersonCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      sellingPrice: Money.fromDouble(
          double.tryParse(_sellingPriceCtrl.text.replaceAll(',', '')) ?? 0),
      discount: Money.fromDouble(
          double.tryParse(_discountCtrl.text.replaceAll(',', '')) ?? 0),
      taxPercentage: int.tryParse(_taxCtrl.text) ?? 0,
      createdAt: widget.station?.createdAt ?? DateTime.now(),
      createdBy: widget.station?.createdBy ?? 'system',
    );

    bool ok;
    if (_isEditing) {
      ok = await context.read<StationProvider>().updateStation(station);
    } else {
      ok = await context.read<StationProvider>().createStation(station);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء الحفظ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomerProvider>().customers;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'تعديل المحطة' : 'محطة جديدة'),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: _save,
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
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
                _SectionHeader(title: 'البيانات الأساسية'),
                const SizedBox(height: 12),

                // Station Number
                TextFormField(
                  controller: _stationNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم المحطة *',
                    prefixIcon: Icon(Icons.tag),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'رقم المحطة مطلوب' : null,
                ),
                const SizedBox(height: 12),

                // Name
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المحطة *',
                    prefixIcon: Icon(Icons.solar_power),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'اسم المحطة مطلوب' : null,
                ),
                const SizedBox(height: 12),

                // Customer dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCustomerId,
                  decoration: const InputDecoration(
                    labelText: 'العميل',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('بدون عميل')),
                    ...customers.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedCustomerId = v),
                ),
                const SizedBox(height: 12),

                // Status
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'حالة المشروع',
                    prefixIcon: Icon(Icons.flag),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'study', child: Text('دراسة')),
                    DropdownMenuItem(value: 'inspection', child: Text('معاينة')),
                    DropdownMenuItem(value: 'pricing', child: Text('تسعير')),
                    DropdownMenuItem(value: 'quotation', child: Text('عرض سعر')),
                    DropdownMenuItem(value: 'contracted', child: Text('تعاقد')),
                    DropdownMenuItem(value: 'under_execution', child: Text('تحت التنفيذ')),
                    DropdownMenuItem(value: 'completed', child: Text('مكتمل')),
                    DropdownMenuItem(value: 'suspended', child: Text('متوقف')),
                    DropdownMenuItem(value: 'cancelled', child: Text('ملغي')),
                  ],
                  onChanged: (v) => setState(() => _selectedStatus = v!),
                ),

                const SizedBox(height: 20),
                _SectionHeader(title: 'الموقع'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'خط العرض',
                          hintText: '30.0444',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final d = double.tryParse(v);
                          if (d == null) return 'رقم غير صالح';
                          if (d < -90 || d > 90) return '-90 إلى 90';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'خط الطول',
                          hintText: '31.2357',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final d = double.tryParse(v);
                          if (d == null) return 'رقم غير صالح';
                          if (d < -180 || d > 180) return '-180 إلى 180';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _SectionHeader(title: 'المساحات (م²)'),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _landAreaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'مساحة الأرض',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _roofAreaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'مساحة السطح',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _availableAreaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'المساحة المتاحة للتركيب',
                    prefixIcon: Icon(Icons.crop_square),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),

                const SizedBox(height: 20),
                _SectionHeader(title: 'التفاصيل التقنية'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _projectTypeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نوع المشروع',
                    prefixIcon: Icon(Icons.category),
                    hintText: 'سكني، تجاري، صناعي...',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _requiredCapacityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'القدرة المطلوبة (kWp)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _totalPanelsCapacityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'قدرة الألواح (kWp)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _responsiblePersonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'المسؤول عن المحطة',
                    prefixIcon: Icon(Icons.engineering),
                  ),
                ),

                const SizedBox(height: 20),
                _SectionHeader(title: 'التسعير'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _sellingPriceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'سعر البيع (ج.م)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _discountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الخصم (ج.م)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _taxCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الضريبة %',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final n = int.tryParse(v);
                          if (n == null || n < 0 || n > 100) {
                            return '0 - 100';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _SectionHeader(title: 'ملاحظات'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    prefixIcon: Icon(Icons.note),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _save,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isEditing ? 'حفظ التعديلات' : 'إنشاء المحطة'),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
      ),
    );
  }
}
