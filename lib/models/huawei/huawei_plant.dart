class HuaweiPlant {
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

  const HuaweiPlant({
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

  factory HuaweiPlant.fromJson(Map<String, dynamic> json) {
    return HuaweiPlant(
      source: _text(_pick(json, ['source', 'provider']), fallback: 'huawei'),
      plantName: _text(
        _pick(json, ['plantName', 'stationName', 'name', 'displayName']),
        fallback: 'Unknown Plant',
      ),
      plantCode: _text(
        _pick(json, ['plantCode', 'providerPlantId', 'stationId', 'id']),
      ),
      capacity: _number(_pick(json, ['capacity', 'capacityKw'])),
      currentPower: _number(
        _pick(json, ['currentPower', 'currentPowerKw', 'power', 'powerKw']),
      ),
      dailyEnergy: _number(
        _pick(json, ['dailyEnergy', 'todayEnergyKwh', 'dayEnergy']),
      ),
      monthlyEnergy: _number(
        _pick(json, ['monthlyEnergy', 'monthEnergyKwh', 'monthEnergy']),
      ),
      yearlyEnergy: _number(
        _pick(json, ['yearlyEnergy', 'yearEnergyKwh', 'yearEnergy']),
      ),
      totalEnergy: _number(
        _pick(json, ['totalEnergy', 'totalEnergyKwh', 'allEnergy']),
      ),
      status: _normalizeStatus(_pick(json, ['status', 'statusText'])),
      address: _text(
        _pick(json, ['address', 'plantAddress', 'addr']) ??
            _nestedText(json, 'location', 'address'),
      ),
      latitude: _text(_pick(json, ['latitude', 'lat'])),
      longitude: _text(_pick(json, ['longitude', 'lng', 'lon'])),
      gridConnectionDate: _textOrNull(
        _pick(json, ['gridConnectionDate', 'gridConnectedAt']),
      ),
      updatedAt: _textOrNull(_pick(json, ['updatedAt', 'dataTimestamp'])),
    );
  }

  HuaweiPlant mergeRealtime(HuaweiPlant realtime) {
    return HuaweiPlant(
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

  static String? _nestedText(
    Map<String, dynamic> json,
    String parent,
    String child,
  ) {
    final value = json[parent];
    if (value is! Map) return null;
    final text = value[child]?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
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
    if (value.isEmpty) return 'unknown';
    if (value.contains('normal') || value.contains('online')) return 'online';
    if (value.contains('alarm') || value.contains('warning')) return 'warning';
    if (value.contains('fault') || value.contains('error')) return 'fault';
    if (value == '1') return 'online';
    if (value == '2') return 'unknown';
    if (value == '3') return 'warning';
    return 'unknown';
  }
}
