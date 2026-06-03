class GrowattPlant {
  final String source;
  final String plantName;
  final String plantCode;
  final double capacity;
  final double currentPower;
  final double dailyEnergy;
  final double monthlyEnergy;
  final double yearlyEnergy;
  final double totalEnergy;
  final String status;
  final String address;
  final String latitude;
  final String longitude;
  final String? gridConnectionDate;
  final String? updatedAt;

  const GrowattPlant({
    required this.source,
    required this.plantName,
    required this.plantCode,
    required this.capacity,
    required this.currentPower,
    required this.dailyEnergy,
    required this.monthlyEnergy,
    required this.yearlyEnergy,
    required this.totalEnergy,
    required this.status,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.gridConnectionDate,
    this.updatedAt,
  });

  factory GrowattPlant.fromJson(Map<String, dynamic> json) {
    return GrowattPlant(
      source: _text(_pick(json, ['source', 'provider']), fallback: 'growatt'),
      plantName: _text(
        _pick(json, ['plantName', 'name', 'displayName']),
        fallback: 'Unknown Plant',
      ),
      plantCode: _text(_pick(json, ['plantCode', 'plant_id', 'id'])),
      capacity: _number(_pick(json, ['capacity', 'peak_power', 'capacityKw'])),
      currentPower: _number(
        _pick(json, ['currentPower', 'current_power', 'power', 'powerKw']),
      ),
      dailyEnergy: _number(
        _pick(json, ['dailyEnergy', 'today_energy', 'dayEnergy']),
      ),
      monthlyEnergy: _number(
        _pick(json, ['monthlyEnergy', 'monthly_energy', 'monthEnergy']),
      ),
      yearlyEnergy: _number(
        _pick(json, ['yearlyEnergy', 'yearly_energy', 'yearEnergy']),
      ),
      totalEnergy: _number(
        _pick(json, ['totalEnergy', 'total_energy', 'allEnergy']),
      ),
      status: _normalizeStatus(_pick(json, ['status', 'statusText'])),
      address: _text(_pick(json, ['address', 'plantAddress', 'city'])),
      latitude: _text(_pick(json, ['latitude', 'lat'])),
      longitude: _text(_pick(json, ['longitude', 'lng', 'lon'])),
      gridConnectionDate: _textOrNull(
        _pick(json, ['gridConnectionDate', 'create_date', 'createDate']),
      ),
      updatedAt: _textOrNull(_pick(json, ['updatedAt', 'last_update_time'])),
    );
  }

  GrowattPlant mergeRealtime(GrowattPlant realtime) {
    return GrowattPlant(
      source: source,
      plantName: plantName,
      plantCode: plantCode,
      capacity: capacity,
      currentPower: realtime.currentPower,
      dailyEnergy: realtime.dailyEnergy,
      monthlyEnergy: realtime.monthlyEnergy,
      yearlyEnergy: realtime.yearlyEnergy,
      totalEnergy: realtime.totalEnergy,
      status: realtime.status == 'unknown' ? status : realtime.status,
      address: address,
      latitude: latitude,
      longitude: longitude,
      gridConnectionDate: gridConnectionDate,
      updatedAt: realtime.updatedAt ?? updatedAt,
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
