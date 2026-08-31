// lib/presentation/screens/dashboard/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/station_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/stat_card.dart';
import '../../../core/theme/app_theme.dart';
import '../stations/stations_list_screen.dart';
import '../customers/customers_list_screen.dart';
import '../items/items_catalog_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    _HomeTab(),
    StationsListScreen(),
    CustomersListScreen(),
    ItemsCatalogScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StationProvider>().loadStats();
      context.read<StationProvider>().loadStations();
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.solar_power_outlined),
              selectedIcon: Icon(Icons.solar_power),
              label: 'المحطات',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'العملاء',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'البنود',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wb_sunny, color: Colors.amber),
            SizedBox(width: 8),
            Text('Solar Manager'),
          ],
        ),
      ),
      body: Consumer<StationProvider>(
        builder: (context, provider, _) {
          final stats = provider.stats;
          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadStats();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مرحباً بك في',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const Text(
                          'Solar Manager',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'نظام إدارة محطات الطاقة الشمسية',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'إحصائيات المحطات',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),

                  if (stats == null)
                    const LoadingWidget()
                  else
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        StatCard(
                          title: 'إجمالي المحطات',
                          value: '${stats.totalStations}',
                          icon: Icons.solar_power,
                          color: AppTheme.primaryColor,
                        ),
                        StatCard(
                          title: 'تحت الدراسة',
                          value: '${stats.studyCount}',
                          icon: Icons.search,
                          color: Colors.blue.shade700,
                        ),
                        StatCard(
                          title: 'تحت التنفيذ',
                          value: '${stats.underExecutionCount}',
                          icon: Icons.construction,
                          color: Colors.orange.shade700,
                        ),
                        StatCard(
                          title: 'مكتملة',
                          value: '${stats.completedCount}',
                          icon: Icons.check_circle,
                          color: AppTheme.successColor,
                        ),
                        StatCard(
                          title: 'إجمالي القدرة',
                          value: '${stats.totalCapacityKwp.toStringAsFixed(1)} kWp',
                          icon: Icons.bolt,
                          color: AppTheme.secondaryColor,
                        ),
                        StatCard(
                          title: 'إجمالي المبيعات',
                          value: _formatMillimes(
                              stats.totalSellingPriceMillimes),
                          icon: Icons.attach_money,
                          color: AppTheme.successColor,
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),
                  Text(
                    'المحطات الأخيرة',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _RecentStationsList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatMillimes(int millimes) {
    final value = millimes / 1000;
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} م';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)} ألف';
    }
    return value.toStringAsFixed(0);
  }
}

class _RecentStationsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<StationProvider>(
      builder: (context, provider, _) {
        final stations = provider.stations.take(5).toList();
        if (stations.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'لا توجد محطات بعد\nاضغط على "المحطات" لإضافة محطة جديدة',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final station = stations[i];
            final statusColor = AppTheme.getStatusColor(station.status);
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(Icons.solar_power, color: statusColor, size: 20),
                ),
                title: Text(
                  station.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(station.stationNumber),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
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
              ),
            );
          },
        );
      },
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
