import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../widgets/common.dart';

/// Screen 11 - Offline Mode
class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final online = state.isOnline;
    final pending = state.pendingSyncCount;

    return Scaffold(
      appBar: simpleAppBar(''),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: Colors.grey.shade200,
                child: Icon(online ? Icons.wifi : Icons.wifi_off,
                    size: 44, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),
              Text(online ? "You're Online" : "You're Offline",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                online
                    ? 'Everything is up to date.'
                    : 'No internet connection detected.\nYou can still process sales, view cached data and manage inventory.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(online ? Icons.cloud_done : Icons.check_circle,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(online ? 'Synced' : 'Working Offline',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('$pending sale(s) waiting to sync',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}
