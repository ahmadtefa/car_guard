// lib/presentation/screens/items/items_catalog_screen.dart

import "../../../core/constants/enums.dart";
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/catalog_item.dart';
import '../../../domain/entities/item_category.dart';
import '../../providers/item_provider.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/loading_widget.dart';

class ItemsCatalogScreen extends StatefulWidget {
  const ItemsCatalogScreen({super.key});

  @override
  State<ItemsCatalogScreen> createState() => _ItemsCatalogScreenState();
}

class _ItemsCatalogScreenState extends State<ItemsCatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('البنود والتصنيفات'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(text: 'البنود'),
            Tab(text: 'التصنيفات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ItemsTab(searchCtrl: _searchCtrl),
          const _CategoriesTab(),
        ],
      ),
    );
  }
}

class _ItemsTab extends StatelessWidget {
  final TextEditingController searchCtrl;
  const _ItemsTab({required this.searchCtrl});

  @override
  Widget build(BuildContext context) {
    return Consumer<ItemProvider>(
      builder: (context, provider, _) {
        if (provider.state == LoadState.loading) {
          return const LoadingWidget();
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: searchCtrl,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'بحث عن بند...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchCtrl.clear();
                            provider.loadAll();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                onChanged: provider.searchItems,
              ),
            ),
            Expanded(
              child: provider.items.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.inventory_2_outlined,
                      title: 'لا توجد بنود',
                      action: ElevatedButton.icon(
                        onPressed: () => _openAddItem(context, provider),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة بند'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: provider.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = provider.items[i];
                        final cat = provider.getCategoryById(item.categoryId);
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.inventory_2,
                                color: Colors.blue),
                            title: Text(item.name,
                                style:
                                    Theme.of(context).textTheme.titleSmall),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (cat != null) Text(cat.nameAr),
                                if (item.brand != null || item.model != null)
                                  Text(
                                      '${item.brand ?? ''} ${item.model ?? ''}'),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.unitPrice.formatWhole(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(color: Colors.blue),
                                ),
                                if (item.unit != null)
                                  Text(item.unit!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                              ],
                            ),
                            onLongPress: () {
                              showModalBottomSheet<void>(
                                context: context,
                                builder: (_) => _ItemOptions(item: item),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _openAddItem(BuildContext context, ItemProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const _ItemFormSheet(),
      ),
    );
  }
}

class _ItemOptions extends StatelessWidget {
  final CatalogItem item;
  const _ItemOptions({required this.item});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('تعديل البند'),
            onTap: () {
              // Capture what we need before popping this sheet: its context
              // is defunct afterwards. The navigator's context stays valid.
              final navigator = Navigator.of(context);
              final provider = context.read<ItemProvider>();
              navigator.pop();
              showModalBottomSheet<void>(
                context: navigator.context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: _ItemFormSheet(item: item),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('حذف البند'),
            onTap: () {
              context.read<ItemProvider>().deleteItem(item.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _ItemFormSheet extends StatefulWidget {
  final CatalogItem? item;
  const _ItemFormSheet({this.item});

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategoryId;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _supplierCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _nameCtrl = TextEditingController(text: i?.name ?? '');
    _unitCtrl = TextEditingController(text: i?.unit ?? '');
    _brandCtrl = TextEditingController(text: i?.brand ?? '');
    _modelCtrl = TextEditingController(text: i?.model ?? '');
    _priceCtrl = TextEditingController(
        text: i != null ? (i.unitPrice.millimes / 1000).toString() : '');
    _supplierCtrl = TextEditingController(text: i?.supplier ?? '');
    _notesCtrl = TextEditingController(text: i?.notes ?? '');
    _descCtrl = TextEditingController(text: i?.description ?? '');
    _selectedCategoryId = i?.categoryId;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _unitCtrl,
      _brandCtrl,
      _modelCtrl,
      _priceCtrl,
      _supplierCtrl,
      _notesCtrl,
      _descCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اختر التصنيف')));
      return;
    }

    final item = CatalogItem(
      id: widget.item?.id ?? IdGenerator.generate(),
      name: _nameCtrl.text.trim(),
      categoryId: _selectedCategoryId!,
      unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      description:
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      unitPrice: Money.fromDouble(
          double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0),
      supplier:
          _supplierCtrl.text.trim().isEmpty ? null : _supplierCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: widget.item?.createdAt ?? DateTime.now(),
    );

    final provider = context.read<ItemProvider>();
    bool ok;
    if (widget.item != null) {
      ok = await provider.updateItem(item);
    } else {
      ok = await provider.createItem(item);
    }
    if (mounted && ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ItemProvider>().itemCategories;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          builder: (context, scrollController) => Column(
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
                      widget.item == null ? 'بند جديد' : 'تعديل البند',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                        onPressed: _save, child: const Text('حفظ')),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'اسم البند *'),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(labelText: 'التصنيف *'),
                        items: categories.map((cat) {
                          return DropdownMenuItem(
                              value: cat.id, child: Text(cat.nameAr));
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCategoryId = v),
                        validator: (v) => v == null ? 'اختر تصنيفاً' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _unitCtrl,
                        decoration: const InputDecoration(
                            labelText: 'الوحدة',
                            hintText: 'قطعة، متر، كيلو...'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _brandCtrl,
                              decoration: const InputDecoration(labelText: 'الماركة'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _modelCtrl,
                              decoration: const InputDecoration(labelText: 'الموديل'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _priceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'سعر الوحدة (ج.م)',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _supplierCtrl,
                        decoration: const InputDecoration(labelText: 'المورد'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(labelText: 'الوصف'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesCtrl,
                        decoration: const InputDecoration(labelText: 'ملاحظات'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ البند'),
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

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ItemProvider>(
      builder: (context, provider, _) {
        final categories = provider.itemCategories;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تصنيفات البنود (${categories.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _addCategory(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('إضافة'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final cat = categories[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.folder, color: Colors.orange),
                      title: Text(cat.nameAr),
                      subtitle: Text(cat.nameEn,
                          style: Theme.of(context).textTheme.bodySmall),
                      trailing: cat.isDefault
                          ? const Chip(label: Text('افتراضي'))
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _addCategory(BuildContext context) {
    final nameArCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تصنيف جديد'),
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameArCtrl,
                decoration: const InputDecoration(labelText: 'الاسم بالعربي'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameEnCtrl,
                decoration: const InputDecoration(labelText: 'الاسم بالإنجليزي'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameArCtrl.text.trim().isEmpty) return;
              final cat = ItemCategory(
                id: IdGenerator.generate(),
                nameAr: nameArCtrl.text.trim(),
                nameEn: nameEnCtrl.text.trim().isEmpty
                    ? nameArCtrl.text.trim()
                    : nameEnCtrl.text.trim(),
                createdAt: DateTime.now(),
              );
              await context.read<ItemProvider>().createItemCategory(cat);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}
