// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jarwinn_monitoring/services/solis_api_client.dart';

void main() {
  test('Fetch Inverters, Batteries, Collectors without StationId', () async {
    final envFile = File('.env');
    if (!envFile.existsSync()) {
      print('Skipping API smoke test because .env is not available.');
      return;
    }
    dotenv.loadFromString(envString: envFile.readAsStringSync());
    final client = SolisApiClient();

    print('--- Loading Inverters ---');
    try {
      final inverters = await client.getAllInverters();
      print('Inverters found: ${inverters.length}');
      if (inverters.isNotEmpty) {
        print(
          'Sample Inverter: SN ${inverters.first.sn}, Name ${inverters.first.inverterName}',
        );
      }
    } catch (e) {
      print('Inverters API Error: $e');
    }

    print('--- Loading Batteries ---');
    try {
      final batteries = await client.getAllBatteries();
      print('Batteries found: ${batteries.length}');
      if (batteries.isNotEmpty) {
        print(
          'Sample Battery: SN ${batteries.first.sn}, Name ${batteries.first.batteryName}',
        );
      }
    } catch (e) {
      print('Batteries API Error: $e');
    }

    print('--- Loading Collectors ---');
    try {
      final collectors = await client.getAllCollectors();
      print('Collectors found: ${collectors.length}');
      if (collectors.isNotEmpty) {
        print(
          'Sample Collector: SN ${collectors.first.sn}, Name ${collectors.first.collectorName}',
        );
      }
    } catch (e) {
      print('Collectors API Error: $e');
    }
  });
}
