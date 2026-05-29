import 'package:intl/intl.dart';

class Station {
  final String id;
  final String stationName;
  final double capacity;
  final String? capacityStr;
  final double? power;
  final double? power1; // raw watts
  final String? powerStr;
  final double? dayEnergy;
  final double? dayEnergy1;
  final String? dayEnergyStr;
  final double? monthEnergy;
  final double? monthEnergy1;
  final String? monthEnergyStr;
  final double? yearEnergy;
  final double? yearEnergy1;
  final String? yearEnergyStr;
  final double? allEnergy;
  final double? allEnergy1; // raw kWh
  final String? allEnergyStr;
  final double? allIncome;
  final String? allIncomeUnit;
  final int? state; // 1=online, 2=offline, 3=alarm
  final int? connectStatus;
  final String? dataTimestamp;
  final int? updateDate; // epoch millis
  final String? addr;
  final int? inverterCount;
  final int? inverterOnlineCount;
  final int? epmCount;
  final int? collectorCount;
  final String? money;
  final double? dayIncome;
  final String? dayIncomeUnit;
  final double? fullHour;
  final String? plantTypeRaw;

  // Status counts from stationStatusVo
  final int? allCount;
  final int? normalCount;
  final int? offlineCount;
  final int? faultCount;

  Station({
    required this.id,
    required this.stationName,
    required this.capacity,
    this.capacityStr,
    this.power,
    this.power1,
    this.powerStr,
    this.dayEnergy,
    this.dayEnergy1,
    this.dayEnergyStr,
    this.monthEnergy,
    this.monthEnergy1,
    this.monthEnergyStr,
    this.yearEnergy,
    this.yearEnergy1,
    this.yearEnergyStr,
    this.allEnergy,
    this.allEnergy1,
    this.allEnergyStr,
    this.allIncome,
    this.allIncomeUnit,
    this.state,
    this.connectStatus,
    this.dataTimestamp,
    this.updateDate,
    this.addr,
    this.inverterCount,
    this.inverterOnlineCount,
    this.epmCount,
    this.collectorCount,
    this.money,
    this.dayIncome,
    this.dayIncomeUnit,
    this.fullHour,
    this.plantTypeRaw,
    this.allCount,
    this.normalCount,
    this.offlineCount,
    this.faultCount,
  });

  bool get isOnline => state == 1;
  bool get isAlarm => state == 3;

  String get statusText {
    if (state == 1) return 'Online';
    if (state == 3) return 'Alarm';
    return 'Offline';
  }

  /// Display value with unit from API (e.g. "31.3 kWh")
  String get dayEnergyDisplay =>
      '${dayEnergy?.toStringAsFixed(1) ?? "0"} ${dayEnergyStr ?? "kWh"}';
  String get monthEnergyDisplay =>
      '${monthEnergy?.toStringAsFixed(1) ?? "0"} ${monthEnergyStr ?? "kWh"}';
  String get yearEnergyDisplay =>
      '${yearEnergy?.toStringAsFixed(1) ?? "0"} ${yearEnergyStr ?? "kWh"}';
  String get allEnergyDisplay =>
      '${allEnergy?.toStringAsFixed(1) ?? "0"} ${allEnergyStr ?? "kWh"}';
  String get powerDisplay =>
      '${power?.toStringAsFixed(2) ?? "0"} ${powerStr ?? "kW"}';
  String get capacityDisplay =>
      '${capacity.toStringAsFixed(1)} ${capacityStr ?? "kWp"}';

  String plantTypeLabel({
    Iterable<String?> inverterModelHints = const [],
    int batteryDeviceCount = 0,
    double? batteryPercent,
    double? batteryPower,
    double? gridPurchasedDayEnergy,
    double? gridSellDayEnergy,
    double? homeLoadTodayEnergy,
  }) {
    final rawHint = (plantTypeRaw ?? '').toUpperCase();
    final modelHint = inverterModelHints
        .whereType<String>()
        .map((e) => e.toUpperCase())
        .join(' ');

    final gridImport = gridPurchasedDayEnergy ?? 0;
    final gridExport = gridSellDayEnergy ?? 0;
    final homeLoad = homeLoadTodayEnergy ?? 0;
    final hasGridFlow = gridImport > 0.01 || gridExport > 0.01;
    final hasOffGridFlow = homeLoad > 0.01 && !hasGridFlow;
    final hasBatterySignal =
        batteryDeviceCount > 0 ||
        (epmCount ?? 0) > 0 ||
        (batteryPercent ?? 0) > 0.01 ||
        (batteryPower?.abs() ?? 0) > 0.001;

    if (_isHybridHint(rawHint) || _isHybridHint(modelHint)) return 'Hybrid';
    if (_isOffGridHint(rawHint) || _isOffGridHint(modelHint)) {
      return 'Off Grid';
    }
    if (_isOnGridHint(rawHint) || _isOnGridHint(modelHint)) return 'On Grid';

    if (hasBatterySignal && hasOffGridFlow) return 'Hybrid';
    if (hasOffGridFlow) return 'Off Grid';
    if (hasBatterySignal) return 'Hybrid';
    if (hasGridFlow) return 'On Grid';
    return 'On Grid';
  }

  /// Formatted update time
  String get formattedUpdateTime {
    final fromDataTimestamp = _formatTimestamp(dataTimestamp);
    if (fromDataTimestamp != null) return fromDataTimestamp;

    final fromUpdateDate = _formatEpoch(updateDate);
    if (fromUpdateDate != null) return fromUpdateDate;

    return '-';
  }

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: (json['id'] ?? json['sno'] ?? '').toString(),
      stationName: json['stationName'] ?? json['sno'] ?? 'Unknown Plant',
      capacity: _parseDouble(json['capacity']),
      capacityStr: json['capacityStr']?.toString(),
      power: _parseDouble(json['power']),
      power1: _parseDouble(json['power1']),
      powerStr: json['powerStr']?.toString(),
      dayEnergy: _parseDouble(json['dayEnergy']),
      dayEnergy1: _parseDouble(json['dayEnergy1']),
      dayEnergyStr: json['dayEnergyStr']?.toString(),
      monthEnergy: _parseDouble(json['monthEnergy']),
      monthEnergy1: _parseDouble(json['monthEnergy1']),
      monthEnergyStr: json['monthEnergyStr']?.toString(),
      yearEnergy: _parseDouble(json['yearEnergy']),
      yearEnergy1: _parseDouble(json['yearEnergy1']),
      yearEnergyStr: json['yearEnergyStr']?.toString(),
      allEnergy: _parseDouble(json['allEnergy']),
      allEnergy1: _parseDouble(json['allEnergy1']),
      allEnergyStr: json['allEnergyStr']?.toString(),
      allIncome: _parseDouble(json['allIncome']),
      allIncomeUnit: json['allIncomeUnit']?.toString(),
      state: _parseInt(json['state']),
      connectStatus: _parseInt(json['connectStatus']),
      dataTimestamp: json['dataTimestamp']?.toString(),
      updateDate: _parseInt(json['updateDate']),
      addr: json['addr']?.toString(),
      inverterCount: _parseInt(json['inverterCount']),
      inverterOnlineCount: _parseInt(json['inverterOnlineCount']),
      epmCount: _parseInt(json['epmCount']),
      collectorCount: _parseInt(
        json['collectorCount'] ?? json['dataloggerCount'],
      ),
      money: json['money']?.toString(),
      dayIncome: _parseDouble(json['dayIncome'] ?? json['dayInCome']),
      dayIncomeUnit: (json['dayIncomeUnit'] ?? json['dayInComeUnit'])
          ?.toString(),
      fullHour: _parseDouble(json['fullHour']),
      plantTypeRaw: _pickPlantTypeRaw(json),
    );
  }

  static String? _pickPlantTypeRaw(Map<String, dynamic> json) {
    const candidateKeys = [
      'stationType',
      'plantType',
      'type',
      'sceneType',
      'gridType',
      'runningMode',
      'workMode',
      'stationMode',
    ];

    for (final key in candidateKeys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static bool _isHybridHint(String hint) {
    if (hint.isEmpty) return false;
    return hint.contains('HYBRID') ||
        hint.contains('HYD') ||
        hint.contains('HYB') ||
        hint.contains('-EH') ||
        hint.contains(' EH') ||
        hint.contains('-ES') ||
        hint.contains(' ES') ||
        hint.contains('RHI');
  }

  static bool _isOffGridHint(String hint) {
    if (hint.isEmpty) return false;
    return hint.contains('OFF GRID') ||
        hint.contains('OFF-GRID') ||
        hint.contains('OFFGRID') ||
        hint.contains('-EO') ||
        hint.contains(' EO') ||
        hint.contains('MICROGRID');
  }

  static bool _isOnGridHint(String hint) {
    if (hint.isEmpty) return false;
    return hint.contains('ON GRID') ||
        hint.contains('ON-GRID') ||
        hint.contains('ONGRID') ||
        hint.contains('-GR') ||
        hint.contains(' GR');
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _formatEpoch(int? epochMs) {
    if (epochMs == null || epochMs <= 0) return null;
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return null;
    }
  }

  static String? _formatTimestamp(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    final epoch = int.tryParse(value);
    if (epoch != null && epoch > 0) {
      return _formatEpoch(epoch);
    }

    // Keep API-provided human-readable timestamp when it's not epoch.
    return value;
  }
}
