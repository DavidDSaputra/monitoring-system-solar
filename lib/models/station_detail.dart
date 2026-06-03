class StationDetail {
  final Map<String, dynamic> raw;
  final String id;
  final String? stationName;
  final double? capacity;
  final String? capacityStr;
  final double? power;
  final String? powerStr;
  final double? dayEnergy;
  final String? dayEnergyStr;
  final double? monthEnergy;
  final String? monthEnergyStr;
  final double? yearEnergy;
  final String? yearEnergyStr;
  final double? allEnergy;
  final String? allEnergyStr;
  final double? allEnergy1; // raw kWh
  final double? dayInCome;
  final String? dayInComeUnit;
  final double? monthInCome;
  final String? monthInComeUnit;
  final double? yearInCome;
  final String? yearInComeUnit;
  final double? allInCome;
  final String? allInComeUnit;
  final double? allIncome;
  final double? fullHour;
  final int? state;
  final String? dataTimestamp;
  final double? batteryPower;
  final String? batteryPowerStr;
  final double? batteryPercent;
  final double? psum;
  final String? psumStr;
  final double? familyLoadPower;
  final String? familyLoadPowerStr;
  final String? addr;

  // Weather fields
  final String? condTxtD;
  final String? condTxtN;
  final String? tmpMax;
  final String? tmpMin;
  final String? tmpUnit;
  final String? winSpe; // wind speed (e.g. "3.4m/s")
  final String? winDir; // wind direction (e.g. "WNW")
  final String? humidity; // humidity % (e.g. "75")
  final String? sunrise; // "05:54"
  final String? sunset; // "17:54"

  // Device counts
  final int? inverterCount;
  final double? inverterPower;
  final String? inverterPowerStr;

  // Grid data
  final double? gridPurchasedDayEnergy;
  final String? gridPurchasedDayEnergyStr;
  final double? gridSellDayEnergy;
  final String? gridSellDayEnergyStr;
  final double? homeLoadTodayEnergy;
  final String? homeLoadTodayEnergyStr;

  // Environmental benefits (from API when available)
  final double? co2Reduce; // CO2 reduction kg
  final double? coalReduction; // Standard coal saved kg
  final double? treeNum; // Equivalent trees planted

  StationDetail({
    required this.raw,
    required this.id,
    this.stationName,
    this.capacity,
    this.capacityStr,
    this.power,
    this.powerStr,
    this.dayEnergy,
    this.dayEnergyStr,
    this.monthEnergy,
    this.monthEnergyStr,
    this.yearEnergy,
    this.yearEnergyStr,
    this.allEnergy,
    this.allEnergyStr,
    this.allEnergy1,
    this.dayInCome,
    this.dayInComeUnit,
    this.monthInCome,
    this.monthInComeUnit,
    this.yearInCome,
    this.yearInComeUnit,
    this.allInCome,
    this.allInComeUnit,
    this.allIncome,
    this.fullHour,
    this.state,
    this.dataTimestamp,
    this.batteryPower,
    this.batteryPowerStr,
    this.batteryPercent,
    this.psum,
    this.psumStr,
    this.familyLoadPower,
    this.familyLoadPowerStr,
    this.addr,
    this.condTxtD,
    this.condTxtN,
    this.tmpMax,
    this.tmpMin,
    this.tmpUnit,
    this.winSpe,
    this.winDir,
    this.humidity,
    this.sunrise,
    this.sunset,
    this.inverterCount,
    this.inverterPower,
    this.inverterPowerStr,
    this.gridPurchasedDayEnergy,
    this.gridPurchasedDayEnergyStr,
    this.gridSellDayEnergy,
    this.gridSellDayEnergyStr,
    this.homeLoadTodayEnergy,
    this.homeLoadTodayEnergyStr,
    this.co2Reduce,
    this.coalReduction,
    this.treeNum,
  });

  bool get isOnline => state == 1;
  String get statusText {
    switch (state) {
      case 1:
        return 'Online';
      case 2:
        return 'Offline';
      case 3:
        return 'Alarm';
      default:
        return 'Unknown';
    }
  }

  /// Display helpers using API-provided units
  String get powerDisplay =>
      '${power?.toStringAsFixed(2) ?? "0"} ${powerStr ?? "kW"}';
  String get dayEnergyDisplay =>
      '${dayEnergy?.toStringAsFixed(1) ?? "0"} ${dayEnergyStr ?? "kWh"}';
  String get monthEnergyDisplay =>
      '${monthEnergy?.toStringAsFixed(1) ?? "0"} ${monthEnergyStr ?? "kWh"}';
  String get yearEnergyDisplay =>
      '${yearEnergy?.toStringAsFixed(1) ?? "0"} ${yearEnergyStr ?? "kWh"}';
  String get allEnergyDisplay =>
      '${allEnergy?.toStringAsFixed(1) ?? "0"} ${allEnergyStr ?? "kWh"}';

  /// Formatted income display (e.g. "5.201k IDR")
  String _formatIncome(double? value, String? unit) {
    if (value == null) return '-';
    String formatted;
    if (value.abs() >= 1000000) {
      formatted = '${(value / 1000000).toStringAsFixed(3)}M';
    } else if (value.abs() >= 1000) {
      formatted = '${(value / 1000).toStringAsFixed(3)}k';
    } else {
      formatted = value.toStringAsFixed(2);
    }
    return unit != null && unit.isNotEmpty ? '$formatted $unit' : formatted;
  }

  String get dayIncomeDisplay => _formatIncome(dayInCome, dayInComeUnit);
  String get monthIncomeDisplay => _formatIncome(monthInCome, monthInComeUnit);
  String get yearIncomeDisplay => _formatIncome(yearInCome, yearInComeUnit);
  String get allIncomeDisplay => _formatIncome(allInCome, allInComeUnit);

  /// Wind display (e.g. "WNW 3.4m/s")
  String get windDisplay {
    final dir = winDir ?? '';
    final spe = winSpe ?? '';
    if (dir.isEmpty && spe.isEmpty) return '-';
    return '${dir.isNotEmpty ? "$dir " : ""}$spe'.trim();
  }

  /// Sunrise/Sunset display (e.g. "05:54 / 17:54")
  String get sunriseSunsetDisplay {
    final sr = sunrise ?? '';
    final ss = sunset ?? '';
    if (sr.isEmpty && ss.isEmpty) return '-';
    if (sr.isEmpty) return ss;
    if (ss.isEmpty) return sr;
    return '$sr / $ss';
  }

  factory StationDetail.fromJson(Map<String, dynamic> json) {
    return StationDetail(
      raw: Map<String, dynamic>.from(json),
      id: (json['id'] ?? json['sno'] ?? '').toString(),
      stationName: json['stationName'],
      capacity: _parseDouble(json['capacity']),
      capacityStr: json['capacityStr']?.toString(),
      power: _parseDouble(json['power']),
      powerStr: json['powerStr']?.toString(),
      dayEnergy: _parseDouble(json['dayEnergy']),
      dayEnergyStr: json['dayEnergyStr']?.toString(),
      monthEnergy: _parseDouble(json['monthEnergy']),
      monthEnergyStr: json['monthEnergyStr']?.toString(),
      yearEnergy: _parseDouble(json['yearEnergy']),
      yearEnergyStr: json['yearEnergyStr']?.toString(),
      allEnergy: _parseDouble(json['allEnergy']),
      allEnergyStr: json['allEnergyStr']?.toString(),
      allEnergy1: _parseDouble(json['allEnergy1']),
      dayInCome: _parseDouble(json['dayInCome']),
      dayInComeUnit: json['dayInComeUnit']?.toString(),
      monthInCome: _parseDouble(json['monthInCome']),
      monthInComeUnit: json['monthInComeUnit']?.toString(),
      yearInCome: _parseDouble(json['yearInCome']),
      yearInComeUnit: json['yearInComeUnit']?.toString(),
      allInCome: _parseDouble(json['allInCome']),
      allInComeUnit: json['allInComeUnit']?.toString(),
      allIncome: _parseDouble(json['allIncome']),
      fullHour: _parseDouble(json['fullHour']),
      state: json['state'] as int?,
      dataTimestamp: json['dataTimestamp']?.toString(),
      batteryPower: _parseDouble(json['batteryPower']),
      batteryPowerStr: json['batteryPowerStr']?.toString(),
      batteryPercent: _parseDouble(json['batteryPercent']),
      psum: _parseDouble(json['psum']),
      psumStr: json['psumStr']?.toString(),
      familyLoadPower: _parseDouble(json['familyLoadPower']),
      familyLoadPowerStr: json['familyLoadPowerStr']?.toString(),
      addr: json['addr']?.toString(),
      condTxtD: json['condTxtD']?.toString(),
      condTxtN: json['condTxtN']?.toString(),
      tmpMax: json['tmpMax']?.toString(),
      tmpMin: json['tmpMin']?.toString(),
      tmpUnit: json['tmpUnit']?.toString(),
      winSpe: json['winSpe']?.toString(),
      winDir: json['winDir']?.toString(),
      humidity: json['humidity']?.toString(),
      sunrise: json['sunrise']?.toString(),
      sunset: json['sunset']?.toString(),
      inverterCount: json['inverterCount'] as int?,
      inverterPower: _parseDouble(json['inverterPower']),
      inverterPowerStr: json['inverterPowerStr']?.toString(),
      gridPurchasedDayEnergy: _parseDouble(json['gridPurchasedDayEnergy']),
      gridPurchasedDayEnergyStr: json['gridPurchasedDayEnergyStr']?.toString(),
      gridSellDayEnergy: _parseDouble(json['gridSellDayEnergy']),
      gridSellDayEnergyStr: json['gridSellDayEnergyStr']?.toString(),
      homeLoadTodayEnergy: _parseDouble(json['homeLoadTodayEnergy']),
      homeLoadTodayEnergyStr: json['homeLoadTodayEnergyStr']?.toString(),
      co2Reduce: _parseDouble(json['co2Reduce'] ?? json['co2']),
      coalReduction: _parseDouble(json['coalReduction'] ?? json['coalWeight']),
      treeNum: _parseDouble(json['treeNum'] ?? json['treesNumber']),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
