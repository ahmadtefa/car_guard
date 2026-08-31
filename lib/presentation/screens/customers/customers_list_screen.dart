// lib/presentation/screens/customers/customers_list_screen.dart

import "../../../core/constants/enums.dart";
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/id_generator.dart';
import '../../../domain/entities/customer.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/loading_widget.dart';

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openAddDialog([Customer? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CustomerFormSheet(customer: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العملاء'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openAddDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'بحث...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          context.read<CustomerProvider>().loadCustomers();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (v) =>
                  context.read<CustomerProvider>().searchCustomers(v),
            ),
          ),
          Expanded(
            child: Consumer<CustomerProvider>(
              builder: (context, provider, _) {
                if (provider.state == LoadState.loading) {
                  return const LoadingWidget();
                }
                if (provider.customers.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.people_outline,
                    title: 'لا يوجد عملاء',
                    subtitle: 'اضغط + لإضافة عميل',
                    action: ElevatedButton.icon(
                      onPressed: () => _openAddDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة عميل'),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: provider.customers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = provider.customers[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Colors.blue.shade100,
                          child: Text(
                            c.name.isNotEmpty
                                ? c.name.characters.first
                                : '?',
                            style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(c.name,
                            style:
                                Theme.of(context).textTheme.titleSmall),
                        subtitle: c.phone != null
                            ? Text(c.phone!)
                            : null,
                        trailing: PopupMenuButton(
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit',
                                child: Text('تعديل')),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Text('حذف',
                                    style:
                                        TextStyle(color: Colors.red))),
                          ],
                          onSelected: (v) async {
                            if (v == 'edit') _openAddDialog(c);
                            if (v == 'delete') {
                              await provider.deleteCustomer(c.id);
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('عميل جديد'),
      ),
    );
  }
}

class _CustomerFormSheet extends StatefulWidget {
  final Customer? customer;
  const _CustomerFormSheet({this.customer});

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _phoneAltCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _governorateCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _notesCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _phoneAltCtrl = TextEditingController(text: c?.phoneAlt ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _governorateCtrl = TextEditingController(text: c?.governorate ?? '');
    _cityCtrl = TextEditingController(text: c?.city ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _phoneAltCtrl,
      _emailCtrl,
      _addressCtrl,
      _governorateCtrl,
      _cityCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final customer = Customer(
      id: widget.customer?.id ?? IdGenerator.generate(),
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      phoneAlt:
          _phoneAltCtrl.text.trim().isEmpty ? null : _phoneAltCtrl.text.trim(),
      email:
          _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      address:
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      governorate: _governorateCtrl.text.trim().isEmpty
          ? null
          : _governorateCtrl.text.trim(),
      city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      notes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: widget.customer?.createdAt ?? DateTime.now(),
    );

    final provider = context.read<CustomerProvider>();
    bool ok;
    if (widget.customer != null) {
      ok = await provider.updateCustomer(customer);
    } else {
      ok = await provider.createCustomer(customer);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.customer == null ? 'عميل جديد' : 'تعديل العميل',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: _save,
                            child: const Text('حفظ'),
                          ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'الاسم *',
                            prefixIcon: Icon(Icons.person)),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'الاسم مطلوب' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                            labelText: 'الهاتف',
                            prefixIcon: Icon(Icons.phone)),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneAltCtrl,
                        decoration: const InputDecoration(
                            labelText: 'هاتف إضافي',
                            prefixIcon: Icon(Icons.phone_android)),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email)),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(
                            labelText: 'العنوان',
                            prefixIcon: Icon(Icons.location_on)),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _governorateCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'المحافظة'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cityCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'المدينة'),
                            ),
                          ),
                        ],
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
                      ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: Text(widget.customer == null
                            ? 'إضافة العميل'
                            : 'حفظ التعديلات'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
