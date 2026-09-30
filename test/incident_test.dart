import 'package:flutter_test/flutter_test.dart';
import 'package:jarwinn_monitoring/models/incident.dart';

void main() {
  test('parses downtime and SLA state from backend', () {
    final incident = Incident.fromJson({
      'id': 'incident-1',
      'entityType': 'inverter',
      'entityId': 'inv-1',
      'entityName': 'Inverter A',
      'source': 'solis',
      'plantCode': 'plant-1',
      'plantName': 'Plant Test',
      'status': 'fault',
      'priority': 'P1',
      'priorityLabel': 'Critical',
      'slaMinutes': 15,
      'startedAt': '2026-09-29T01:00:00Z',
      'slaDueAt': '2026-09-29T01:15:00Z',
      'resolvedAt': '2026-09-29T01:25:00Z',
      'durationSeconds': 1500,
      'slaBreached': true,
      'isOpen': false,
      'address': 'Jakarta',
    });

    expect(incident.priority, 'P1');
    expect(incident.durationLabel, '25 menit');
    expect(incident.slaBreached, isTrue);
    expect(incident.isOpen, isFalse);
    expect(incident.hasLocation, isTrue);
  });
}
