// lib/presentation/screens/stations/station_detail_screen.dart

import '../../core/constants/enums.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/project_status.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/station.dart';
import '../../domain/entities/station_item.dart';
import '../../providers/customer_provider.dart';
import '../../providers/item_provider.dart';
import '../../providers/station_provider.dart';
import '../../widgets/common/loading_widget.dart';
import 'add_edit_station_screen.dart';
import 'add_station_item_screen.dart';
import 'add_expense_screen.dart';

class StationDetailScreen extends StatefulWidget {
  final String stationId;
  const StationDetailScreen({super.key, required this.stationId});

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<StationProvider>()
          .loadStationDetail(widget.stationId);
      context.read<ItemProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Consumer<StationProvider>(
        builder: (context, provider, _) {
          if (provider.detailState == LoadState.loading) {
            return const Scaffold(body: LoadingWidget(message: 'جاري التحميل...'));
          }
          if (provider.detailState == LoadState.error) {
            return Scaffold(
              body: Center(child: Text(provider.detailError ?? 'خطأ')),
            );
          }
          final station = provider.currentStation;
          if (station == null) return const Scaffold(body: SizedBox());

          final statusColor = AppTheme.getStatusColor(station.status);
          final customer = context
              .read<CustomerProvider>()
              .getById(station.customerId ?? '');

          return Scaffold(
            appBar: AppBar(
              title: Text(station.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddEditStationScreen(station: station),
                      ),
                    );
                    if (updated == true) {
                      context
                          .read<StationProvider>()
                          .loadStationDetail(widget.stationId);
                    }
                  },
                ),
                PopupMenuButton(
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف المحطة',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (v) async {
                    if (v == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('حذف المحطة'),
                          content: const Text(
                              'هل أنت متأكد من حذف هذه المحطة؟ لا يمكن التراجع.'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('إلغاء')),
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('حذف',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        await context
                            .read<StationProvider>()
                            .deleteStation(station.id);
                        if (mounted) Navigator.pop(context);
                      }
                    }
                  },
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.amber,
                tabs: const [
                  Tab(text: 'معلومات'),
                  Tab(text: 'بنود'),
                  Tab(text: 'مصاريف'),
                  Tab(text: 'مالي'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Info
                _InfoTab(station: station, customer: customer),

                // Tab 2: Items
                _ItemsTab(stationId: station.id),

                // Tab 3: Expenses
                _ExpensesTab(stationId: station.id),

                // Tab 4: Financial
                _FinancialTab(stationId: station.id),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ========== INFO TAB ==========
class _InfoTab extends StatelessWidget {
  final Station station;
  final Customer? customer;
  const _InfoTab({required this.station, required this.customer});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.getStatusColor(station.status)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.getStatusColor(station.status)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.flag,
                    color: AppTheme.getStatusColor(station.status)),
                const SizedBox(width: 8),
                Text(
                  _statusName(station.status),
                  style: TextStyle(
                    color: AppTheme.getStatusColor(station.status),
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                  ),
                ),
                const Spacer(),
                Text(
                  station.stationNumber,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Basic Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow('رقم المحطة', station.stationNumber),
                  if (customer != null) _InfoRow('العميل', customer!.name),
                  if (customer?.phone != null && customer!.phone!.isNotEmpty)
                    _InfoRow('هاتف العميل', customer!.phone!),
                  if (station.address != null)
                    _InfoRow('العنوان', station.address!),
                  if (station.responsiblePerson != null)
                    _InfoRow('المسؤول', station.responsiblePerson!),
                  if (station.projectType != null)
                    _InfoRow('نوع المشروع', station.projectType!),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Technical
          if (station.requiredCapacityKwp != null ||
              station.totalPanelsCapacityKwp != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('التفاصيل التقنية',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    if (station.requiredCapacityKwp != null)
                      _InfoRow('القدرة المطلوبة',
                          '${station.requiredCapacityKwp} kWp'),
                    if (station.totalPanelsCapacityKwp != null)
                      _InfoRow('قدرة الألواح',
                          '${station.totalPanelsCapacityKwp} kWp'),
                    if (station.landArea != null)
                      _InfoRow('مساحة الأرض', '${station.landArea} م²'),
                    if (station.roofArea != null)
                      _InfoRow('مساحة السطح', '${station.roofArea} م²'),
                    if (station.availableArea != null)
                      _InfoRow(
                          'المساحة المتاحة', '${station.availableArea} م²'),
                  ],
                ),
              ),
            ),

          // Location
          if (station.latitude != null && station.longitude != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الموقع الجغرافي',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _InfoRow('خط العرض', station.latitude.toString()),
                    _InfoRow('خط الطول', station.longitude.toString()),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        // URL launcher would go here in full implementation
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'الموقع: ${station.latitude}, ${station.longitude}'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('فتح على الخريطة'),
                    ),
                  ],
                ),
              ),
            ),

          // Notes
          if (station.notes != null && station.notes!.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ملاحظات',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(station.notes!),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _statusName(String status) {
    for (final s in ProjectStatus.defaults) {
      if (s['key'] == status) return s['nameAr'] ?? status;
    }
    return status;
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== ITEMS TAB ==========
class _ItemsTab extends StatelessWidget {
  final String stationId;
  const _ItemsTab({required this.stationId});

  @override
  Widget build(BuildContext context) {
    return Consumer<StationProvider>(
      builder: (context, provider, _) {
        final items = provider.currentItems;
        Money total = Money.fromMillimes(0);
        for (final i in items) {
          total = total + i.total;
        }
        return Column(
          children: [
            // Total bar
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('إجمالي البنود: ${items.length}',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    total.format(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('لا توجد بنود',
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _addItem(context),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة بند'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return _StationItemCard(
                          item: item,
                          onDelete: () {
                            provider.deleteStationItem(item.id, stationId);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _addItem(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddStationItemScreen(stationId: stationId),
      ),
    );
  }
}

class _StationItemCard extends StatelessWidget {
  final StationItem item;
  final VoidCallback onDelete;
  const _StationItemCard({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.description,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (item.brand != null || item.model != null)
              Text(
                [item.brand, item.model].whereType<String>().join(' - '),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                _SmallChip(
                    '${item.quantity.toString()} ${item.unit ?? ''}'),
                const SizedBox(width: 8),
                _SmallChip('× ${item.unitPriceSnapshot.format()}'),
                const Spacer(),
                Text(
                  item.total.format(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String text;
  const _SmallChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 11, fontFamily: 'Cairo')),
    );
  }
}

// ========== EXPENSES TAB ==========
class _ExpensesTab extends StatelessWidget {
  final String stationId;
  const _ExpensesTab({required this.stationId});

  @override
  Widget build(BuildContext context) {
    return Consumer<StationProvider>(
      builder: (context, provider, _) {
        final expenses = provider.currentExpenses;
        Money total = Money.fromMillimes(0);
        for (final e in expenses) {
          total = total + e.total;
        }
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.warningColor.withValues(alpha: 0.08),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('إجمالي المصاريف: ${expenses.length}',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    total.format(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: expenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_outlined,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('لا توجد مصاريف',
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _addExpense(context),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة مصروف'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: expenses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final exp = expenses[i];
                        return _ExpenseCard(
                          expense: exp,
                          onDelete: () {
                            provider.deleteExpense(exp.id, stationId);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _addExpense(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(stationId: stationId),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback onDelete;
  const _ExpenseCard({required this.expense, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.receipt_long,
                color: AppTheme.warningColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.description,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    '${expense.quantity.toString()} × ${expense.unitPrice.format()}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                  if (expense.addedBy != null)
                    Text(
                      expense.addedBy!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  expense.total.format(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ========== FINANCIAL TAB ==========
class _FinancialTab extends StatelessWidget {
  final String stationId;
  const _FinancialTab({required this.stationId});

  @override
  Widget build(BuildContext context) {
    return Consumer<StationProvider>(
      builder: (context, provider, _) {
        final summary = provider.financialSummary;
        if (summary == null) {
          return const LoadingWidget();
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Cost breakdown
              _FinancialCard(
                title: 'تفصيل التكاليف',
                children: [
                  _FinancialRow('تكلفة المواد', summary.materialCost),
                  _FinancialRow('تكلفة العمالة', summary.laborCost),
                  _FinancialRow('تكلفة النقل', summary.transportationCost),
                  _FinancialRow('مصاريف أخرى', summary.otherExpenses),
                  const Divider(),
                  _FinancialRow(
                    'إجمالي التكلفة الفعلية',
                    summary.totalActualCost,
                    highlight: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Selling
              _FinancialCard(
                title: 'التسعير',
                children: [
                  _FinancialRow('سعر البيع', summary.sellingPrice),
                  _FinancialRow('الخصم', -summary.discount),
                  if (summary.taxPercentage > 0)
                    _FinancialRow(
                        'الضريبة (${summary.taxPercentage}%)',
                        summary.taxAmount),
                  const Divider(),
                  _FinancialRow(
                    'صافي قيمة البيع',
                    summary.netSellingValue,
                    highlight: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Profit
              Card(
                color: summary.isProfitable
                    ? AppTheme.successColor.withValues(alpha: 0.08)
                    : AppTheme.errorColor.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'صافي الربح',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            summary.profit.format(),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: summary.isProfitable
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'هامش الربح',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                          Text(
                            '${summary.profitMarginPercent.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: summary.isProfitable
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FinancialCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  final String label;
  final Money value;
  final bool highlight;
  const _FinancialRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
              fontSize: highlight ? 15 : 14,
            ),
          ),
          Text(
            value.format(),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              fontSize: highlight ? 15 : 14,
              color: highlight ? AppTheme.primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }
}
