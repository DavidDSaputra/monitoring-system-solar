import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarwinn_monitoring/widgets/plant_health_banner.dart';

void main() {
  test('formats a recent timestamp as relative time', () {
    final result = PlantSyncTime.format(
      '2026-09-28T14:55:00',
      now: DateTime(2026, 9, 28, 15),
    );

    expect(result, '5 menit lalu');
  });

  test('formats epoch seconds', () {
    final timestamp =
        DateTime(2026, 9, 28, 14, 30).millisecondsSinceEpoch ~/ 1000;
    final result = PlantSyncTime.format(
      '$timestamp',
      now: DateTime(2026, 9, 28, 15),
    );

    expect(result, '30 menit lalu');
  });

  testWidgets('shows offline plant alert and refresh action', (tester) async {
    var refreshed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlantHealthBanner(
            providerName: 'FusionSolar',
            isOnline: false,
            statusLabel: 'offline',
            accentColor: Colors.blue,
            updatedAt: '2026-09-28T14:55:00',
            onRefresh: () => refreshed = true,
          ),
        ),
      ),
    );

    expect(find.text('Plant sedang offline'), findsOneWidget);
    expect(find.textContaining('Periksa koneksi inverter'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh data'));
    expect(refreshed, isTrue);
  });

  testWidgets('shows device issue while plant stays online', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlantHealthBanner(
            providerName: 'Growatt',
            isOnline: true,
            statusLabel: 'online',
            accentColor: Colors.green,
            offlineDevices: 2,
            totalDevices: 4,
          ),
        ),
      ),
    );

    expect(find.text('2 perangkat perlu diperiksa'), findsOneWidget);
    expect(
      find.text('2 dari 4 perangkat tidak berstatus online.'),
      findsOneWidget,
    );
  });
}
