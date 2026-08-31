// lib/presentation/screens/stations/stations_list_screen.dart

import "../../../core/constants/enums.dart";
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/station_provider.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/loading_widget.dart';
import 'add_edit_station_screen.dart';
import 'station_detail_screen.dart';

class StationsListScreen extends StatefulWidget {
  const StationsListScreen({super.key});

  @override
  State<StationsListScreen> createState() => _StationsListScreenState();
}

class _StationsListScreenState extends State<StationsListScreen> {
  final _searchController = TextEditingController();
  String? _selectedStatus;

  static const _statusOptions = [
    {'key': null, 'name': 'الكل'},
    {'key': 'study', 'name': 'دراسة'},
    {'key': 'inspection', 'name': 'معاينة'},
    {'key': 'pricing', 'name': 'تسعير'},
    {'key': 'quotation', 'name': 'عرض سعر'},
    {'key': 'contracted', 'name': 'تعاقد'},
    {'key': 'under_execution', 'name': 'تحت التنفيذ'},
    {'key': 'completed', 'name': 'مكتمل'},
    {'key': 'suspended', 'name': 'متوقف'},
    {'key': 'cancelled', 'name': 'ملغي'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StationProvider>().loadStations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _doSearch() {
    context.read<StationProvider>().loadStations(
          query: _searchController.text,
          status: _selectedStatus,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحطات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'محطة جديدة',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AddEditStationScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'بحث باسم المحطة أو رقمها أو العميل...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _doSearch();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  onChanged: (_) => _doSearch(),
                ),
                const SizedBox(height: 8),
                // Status filter chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statusOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final opt = _statusOptions[i];
                      final isSelected = _selectedStatus == opt['key'];
                      return FilterChip(
                        label: Text(opt['name'] as String,
                            style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedStatus = opt['key']);
                          _doSearch();
                        },
                        selectedColor:
                            AppTheme.primaryColor.withValues(alpha: 0.2),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: Consumer<StationProvider>(
              builder: (context, provider, _) {
                if (provider.stationsState == LoadState.loading) {
                  return const LoadingWidget(message: 'جاري التحميل...');
                }
                if (provider.stationsState == LoadState.error) {
                  return Center(child: Text(provider.stationsError ?? 'خطأ'));
                }
                if (provider.stations.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.solar_power_outlined,
                    title: 'لا توجد محطات',
                    subtitle: 'اضغط على + لإضافة محطة جديدة',
                    action: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AddEditStationScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة محطة'),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => context.read<StationProvider>().loadStations(
                        query: _searchController.text,
                        status: _selectedStatus,
                      ),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: provider.stations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final station = provider.stations[i];
                      final statusColor =
                          AppTheme.getStatusColor(station.status);
                      final customer = context
                          .read<CustomerProvider>()
                          .getById(station.customerId ?? '');

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    StationDetailScreen(stationId: station.id),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        station.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        station.stationNumber,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: Colors.grey.shade600),
                                      ),
                                      if (customer != null)
                                        Text(
                                          customer.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _statusName(station.status),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 11,
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (station.requiredCapacityKwp != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${station.requiredCapacityKwp} kWp',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: Colors.grey.shade600),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const AddEditStationScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('محطة جديدة'),
      ),
    );
  }

  String _statusName(String status) {
    const map = {
      'study': 'دراسة',
      'inspection': 'معاينة',
      'pricing': 'تسعير',
      'quotation': 'عرض سعر',
      'contracted': 'تعاقد',
      'under_execution': 'تحت التنفيذ',
      'completed': 'مكتمل',
      'suspended': 'متوقف',
      'cancelled': 'ملغي',
    };
    return map[status] ?? status;
  }
}
