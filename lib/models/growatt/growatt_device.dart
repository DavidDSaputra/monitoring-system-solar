class GrowattDevice {
  final String id;
  final String name;
  final String sn;
  final String type;
  final String status;
  final double currentPower;
  final double dailyEnergy;
  final double totalEnergy;
  final String? updatedAt;

  const GrowattDevice({
    required this.id,
    required this.name,
    required this.sn,
    required this.type,
    required this.status,
    required this.currentPower,
    required this.dailyEnergy,
    required this.totalEnergy,
    this.updatedAt,
  });

  factory GrowattDevice.fromJson(Map<String, dynamic> json) {
    final id = _text(_pick(json, ['id', 'deviceId', 'device_id']));
    final sn = _text(_pick(json, ['sn', 'deviceSn', 'device_sn']));
    return GrowattDevice(
      id: id.isNotEmpty ? id : sn,
      name: _text(
        _pick(json, ['name', 'deviceName', 'model']),
        fallback: sn.isNotEmpty ? sn : 'Growatt Device',
      ),
      sn: sn,
      type: _text(_pick(json, ['type', 'deviceType', 'device_type'])),
      status: _normalizeStatus(_pick(json, ['status', 'state'])),
      currentPower: _number(_pick(json, ['currentPower', 'pac', 'power'])),
      dailyEnergy: _number(_pick(json, ['dailyEnergy', 'power_today'])),
      totalEnergy: _number(_pick(json, ['totalEnergy', 'power_total'])),
      updatedAt: _textOrNull(_pick(json, ['updatedAt', 'last_update_time'])),
    );
  }

  bool get isOnline => status == 'online';

  static dynamic _pick(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      return value;
    }
    return null;
  }

  static String _text(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String? _textOrNull(dynamic value) {
    final text = _text(value);
    return text.isEmpty ? null : text;
  }

  static double _number(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static String _normalizeStatus(dynamic raw) {
    final value = _text(raw).toLowerCase();
    if (value.contains('normal') || value.contains('online') || value == '1') {
      return 'online';
    }
    if (value.contains('alarm') || value.contains('warning')) {
      return 'warning';
    }
    if (value.contains('fault') || value.contains('error') || value == '3') {
      return 'fault';
    }
    return 'unknown';
  }
}
