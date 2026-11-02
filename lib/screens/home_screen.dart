import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../routes.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import 'customers_screen.dart';
import 'inventory_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';

/// Screen 3 - Home / Dashboard, plus the bottom navigation shell.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (!state.isOnline) const _OfflineBanner(),
            if (state.cloudSyncError != null)
              _CloudSyncBanner(message: state.cloudSyncError!),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  _Dashboard(),
                  ProductsScreen(embedded: true),
                  InventoryScreen(embedded: true),
                  CustomersScreen(embedded: true),
                  SettingsScreen(embedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        height: 64,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, Routes.offline),
      child: Container(
        width: double.infinity,
        color: Colors.orange.shade100,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.wifi_off, size: 16, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            Text(
              'Working offline - changes are saved on this device and sync when online',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloudSyncBanner extends StatelessWidget {
  final String message;

  const _CloudSyncBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 17,
            color: Colors.amber.shade900,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dashboard extends StatefulWidget {
  const _Dashboard();

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  late Timer _greetingTimer;
  String _greeting = _greetingFor(DateTime.now());

  int _notificationCount(AppState state) =>
      state.lowStock.length +
      (state.cloudSyncError != null ? 1 : 0) +
      (state.pendingSyncCount > 0 || !state.isOnline ? 1 : 0);

  void _showNotifications(AppState state) {
    final alerts = <Widget>[];
    if (!state.isOnline) {
      alerts.add(
        const ListTile(
          leading: Icon(Icons.wifi_off, color: Colors.orange),
          title: Text('Working offline'),
          subtitle: Text(
            'Changes are saved on this device and will sync when online.',
          ),
        ),
      );
    } else if (state.pendingSyncCount > 0) {
      alerts.add(
        ListTile(
          leading: const Icon(
            Icons.cloud_upload_outlined,
            color: Colors.orange,
          ),
          title: const Text('Sales waiting to sync'),
          subtitle: Text(
            '${state.pendingSyncCount} sale(s) are waiting to sync.',
          ),
        ),
      );
    }
    if (state.cloudSyncError case final error?) {
      alerts.add(
        ListTile(
          leading: const Icon(Icons.cloud_off_outlined, color: Colors.red),
          title: const Text('Cloud sync issue'),
          subtitle: Text(error),
        ),
      );
    }
    for (final product in state.lowStock) {
      alerts.add(
        ListTile(
          leading: Icon(
            product.stock == 0 ? Icons.error_outline : Icons.warning_amber,
            color: product.stock == 0 ? Colors.red : Colors.orange,
          ),
          title: Text(product.stock == 0 ? 'Out of stock' : 'Low stock'),
          subtitle: Text('${product.name}: ${product.stock} left'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, Routes.inventory);
          },
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(
                'Notifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            if (alerts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('You’re all caught up.')),
              )
            else
              Flexible(child: ListView(shrinkWrap: true, children: alerts)),
          ],
        ),
      ),
    );
  }

  void _showAccountDetails(AppState state, Color primary) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: primary.withValues(alpha: 0.12),
              child: Icon(Icons.person, size: 32, color: primary),
            ),
            const SizedBox(height: 12),
            Text(
              state.ownerName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(state.account, style: TextStyle(color: Colors.grey.shade600)),
            const Divider(height: 28),
            ListTile(
              leading: Icon(Icons.storefront_outlined, color: primary),
              title: Text(state.businessName),
              subtitle: Text(state.businessType),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log out', style: TextStyle(color: Colors.red)),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Log out?'),
                    content: const Text(
                      'You can sign back in to access your account.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !mounted) return;
                await state.logout();
                if (mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil(Routes.login, (_) => false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Refresh regularly so the greeting follows the device's local time even
    // when the dashboard remains open across a time-of-day change.
    _greetingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final greeting = _greetingFor(DateTime.now());
      if (greeting != _greeting && mounted) {
        setState(() => _greeting = greeting);
      }
    });
  }

  @override
  void dispose() {
    _greetingTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final primary = Theme.of(context).colorScheme.primary;
    final change = state.todayChangePercent;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_greeting,',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  Text(
                    state.ownerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => _showNotifications(state),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none),
                  if (_notificationCount(state) > 0)
                    Positioned(
                      right: -6,
                      top: -5,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _notificationCount(state) > 9
                              ? '9+'
                              : '${_notificationCount(state)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Account details',
              onPressed: () => _showAccountDetails(state, primary),
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: primary.withValues(alpha: 0.15),
                child: Icon(Icons.person, size: 18, color: primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.20),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Sales",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ugx(state.todaySales),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(0)}% vs yesterday',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.bar_chart, color: Colors.white70, size: 36),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.1,
          children: [
            _Quick(
              Icons.shopping_cart_outlined,
              'New Sale',
              () => Navigator.pushNamed(context, Routes.products),
            ),
            _Quick(
              Icons.inventory_2_outlined,
              'Inventory',
              () => Navigator.pushNamed(context, Routes.inventory),
            ),
            _Quick(
              Icons.people_outline,
              'Customers',
              () => Navigator.pushNamed(context, Routes.customers),
            ),
            _Quick(
              Icons.bar_chart,
              'Reports',
              () => Navigator.pushNamed(context, Routes.reports),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Recent Transactions',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (state.recentSales.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('No transactions yet')),
          ),
        ...state.recentSales.map(
          (s) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7ECE9)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF18345A).withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(methodIcon(s.method), color: primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.method} Sale',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        s.customer,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      ugx(s.total),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      fmtTime(s.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _greetingFor(DateTime time) {
  if (time.hour < 12) return 'Good morning';
  if (time.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Quick(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7ECE9)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF18345A).withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
