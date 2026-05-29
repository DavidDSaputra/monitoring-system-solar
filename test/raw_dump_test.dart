import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jarwinn_monitoring/services/solis_api_client.dart';

void main() {
  test('Dump raw inverter record', () async {
    HttpOverrides.global = null;
    dotenv.loadFromString(
      envString: File('c:/laragon/www/jarwinn-monitoring/.env').readAsStringSync(),
    );

    final client = SolisApiClient();

    try {
      final inverters = await client.getInverterList(pageSize: 1);
      debugPrint('Inverters fetched: ${inverters.length}');
      await client.getUserStationList(pageNo: 1, pageSize: 1);
    } catch (e) {
      debugPrint('Error: $e');
    }
  });
}
