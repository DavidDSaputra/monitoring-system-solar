class HuaweiDevice {
  final String id;
  final String name;
  final String sn;
  final String type;
  final String status;
  final double currentPower;
  final double dailyEnergy;
  final double totalEnergy;
  final String? updatedAt;

  const HuaweiDevice({
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

  factory HuaweiDevice.fromJson(Map<String, dynamic> json) {
    final id = _text(_pick(json, ['id', 'devId', 'deviceId', 'esn']));
    final sn = _text(_pick(json, ['sn', 'esn', 'devDn', 'deviceSn']));
    return HuaweiDevice(
      id: id.isNotEmpty ? id : sn,
      name: _text(
        _pick(json, ['name', 'devName', 'deviceName', 'model']),
        fallback: sn.isNotEmpty ? sn : 'Huawei Device',
      ),
      sn: sn,
      type: _text(
        _pick(json, ['type', 'devTypeId', 'deviceType']),
        fallback: 'Device',
      ),
      status: _normalizeStatus(
        _pick(json, ['status', 'runningStatus', 'state']),
      ),
      currentPower: _number(
        _pick(json, ['currentPower', 'activePower', 'power']),
      ),
      dailyEnergy: _number(_pick(json, ['dailyEnergy', 'day_power', 'eToday'])),
      totalEnergy: _number(
        _pick(json, ['totalEnergy', 'total_power', 'eTotal']),
      ),
      updatedAt: _textOrNull(_pick(json, ['updatedAt', 'dataTimestamp'])),
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
    if (value.contains('alarm') || value.contains('warning') || value == '3') {
      return 'warning';
    }
    if (value.contains('fault') || value.contains('error')) return 'fault';
    return 'unknown';
  }
}
