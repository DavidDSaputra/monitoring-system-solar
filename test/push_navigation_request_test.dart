import 'package:flutter_test/flutter_test.dart';
import 'package:jarwinn_monitoring/services/push_notification_service.dart';

void main() {
  group('PushNavigationRequest', () {
    test('parses a plant alarm destination', () {
      final request = PushNavigationRequest.fromData({
        'type': 'plant_status',
        'source': 'huawei',
        'plantCode': 'plant-42',
        'plantName': 'Gudang Timur',
        'event': 'issue',
        'status': 'warning',
        'tab': 'alarm',
      });

      expect(request, isNotNull);
      expect(request!.source, 'huawei');
      expect(request.plantCode, 'plant-42');
      expect(request.plantName, 'Gudang Timur');
      expect(request.showAlarm, isTrue);
    });

    test('rejects payloads without a supported plant destination', () {
      expect(
        PushNavigationRequest.fromData({'type': 'test', 'event': 'manual'}),
        isNull,
      );
    });

    test('accepts a device alert and routes it through its plant', () {
      final request = PushNavigationRequest.fromData({
        'type': 'device_status',
        'source': 'growatt',
        'plantCode': 'growatt-plant',
        'plantName': 'Warehouse',
        'entityType': 'inverter',
        'entityId': 'inv-10',
        'event': 'issue',
        'status': 'fault',
      });

      expect(request, isNotNull);
      expect(request!.source, 'growatt');
      expect(request.showAlarm, isTrue);
    });
  });
}
