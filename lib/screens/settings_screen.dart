import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../routes.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// Screen 10 - Settings
class SettingsScreen extends StatelessWidget {
  final bool embedded;
  const SettingsScreen({super.key, this.embedded = false});

  void _sheet(
    BuildContext context,
    String title,
    Widget Function(BuildContext) body,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            body(ctx),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final primary = Theme.of(context).colorScheme.primary;

    Widget tile(IconData icon, String label, VoidCallback onTap) => ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );

    return Scaffold(
      appBar: simpleAppBar('Settings', back: !embedded),
      body: ListView(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primary.withValues(alpha: 0.15),
                  child: Icon(Icons.person, color: primary),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.ownerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      state.account,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                tile(
                  Icons.storefront_outlined,
                  'Business Profile',
                  () => Navigator.pushNamed(context, Routes.profile),
                ),
                tile(Icons.credit_card, 'Payment Settings', () {
                  _sheet(
                    context,
                    'Payment Settings',
                    (ctx) => Consumer<AppState>(
                      builder: (_, s, _) => Column(
                        children: [
                          ...s.enabledMethods.keys.map(
                            (m) => SwitchListTile(
                              title: Text(methodLabel(m)),
                              value: s.enabledMethods[m] ?? true,
                              onChanged: (v) => s.toggleMethod(m, v),
                            ),
                          ),
                          ListTile(
                            title: const Text('Tax rate'),
                            trailing: Text(
                              '${(s.taxRate * 100).toStringAsFixed(0)}%',
                            ),
                            onTap: () => _numberDialog(
                              ctx,
                              'Tax rate (%)',
                              (s.taxRate * 100).toStringAsFixed(0),
                              (v) => s.setTaxRate(v / 100),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                tile(Icons.inventory_2_outlined, 'Inventory Settings', () {
                  _numberDialog(
                    context,
                    'Default reorder level',
                    '${state.defaultReorder}',
                    (v) => state.setDefaultReorder(v.round()),
                  );
                }),
                tile(Icons.people_outline, 'User Management', () {
                  _sheet(
                    context,
                    'Users',
                    (_) => ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: Text(state.ownerName),
                      subtitle: Text('${state.account} - Owner'),
                    ),
                  );
                }),
                tile(Icons.tune, 'App Preferences', () {
                  _sheet(
                    context,
                    'App Preferences',
                    (_) => Consumer<AppState>(
                      builder: (_, s, _) => SwitchListTile(
                        title: const Text('Work offline'),
                        subtitle: const Text(
                          'Force offline mode (sales sync later)',
                        ),
                        value: s.forceOffline,
                        onChanged: s.setForceOffline,
                      ),
                    ),
                  );
                }),
                tile(Icons.security_outlined, 'Security & Privacy', () {
                  _sheet(
                    context,
                    'Security & Privacy',
                    (ctx) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sign-in is secured by Firebase Authentication. Business data stays on this device and is only used to run your POS.',
                        ),
                        const SizedBox(height: 14),
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Log out'),
                          onTap: () async {
                            await state.logout();
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              Routes.login,
                              (_) => false,
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          title: const Text(
                            'Erase all local data',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await state.resetData();
                            if (context.mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                Routes.login,
                                (_) => false,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
                tile(Icons.info_outline, 'About', () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'POS Retail Pro',
                    applicationVersion: '1.0.0',
                    applicationLegalese: 'Simple. Secure. Offline ready.',
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _numberDialog(
    BuildContext context,
    String title,
    String initial,
    void Function(double) onSave,
  ) {
    final c = TextEditingController(text: initial);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, keyboardType: TextInputType.number),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(c.text);
              if (v != null && v >= 0) onSave(v);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
