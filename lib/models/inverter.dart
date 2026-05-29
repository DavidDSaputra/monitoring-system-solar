class Inverter {
  final String id;
  final String sn;
  final String? inverterName;
  final String? stationId;
  final String? stationName;
  final double? pac; // Real-time power (unit in pacStr)
  final String? pacStr;
  final double? power; // Installed capacity
  final String? powerStr;
  final double? eToday;
  final String? eTodayStr;
  final double? eMonth;
  final String? eMonthStr;
  final double? eYear;
  final String? eYearStr;
  final double? eTotal;
  final String? eTotalStr;
  final double? eTotal1; // raw kWh
  final int? state; // 1=online, 2=offline, 3=alarm
  final int? dataTimestamp;
  final String? dataTimestampStr;
  final double? uAc1;
  final double? iAc1;
  final double? uAc2;
  final double? iAc2;
  final double? uAc3;
  final double? iAc3;
  final double? uPv1; // DC voltage string 1
  final double? iPv1; // DC current string 1
  final double? uPv2; // DC voltage string 2
  final double? iPv2; // DC current string 2
  final double? uDc1;
  final double? iDc1;
  final double? fac;
  final String? facStr;
  final double? ratedPower;
  final double? fullHour;
  final double? totalFullHour;
  final String? collectorSn;
  final int? stateExceptionFlag;
  final String? productModel;

  // Battery related fields (returned for Hybrid inverters)
  final double? batteryCapacitySoc;
  final double? batteryPower;
  final double? batteryTotalChargeEnergy;
  final double? batteryTotalDischargeEnergy;

  Inverter({
    required this.id,
    required this.sn,
    this.inverterName,
    this.stationId,
    this.stationName,
    this.pac,
    this.pacStr,
    this.power,
    this.powerStr,
    this.eToday,
    this.eTodayStr,
    this.eMonth,
    this.eMonthStr,
    this.eYear,
    this.eYearStr,
    this.eTotal,
    this.eTotalStr,
    this.eTotal1,
    this.state,
    this.dataTimestamp,
    this.dataTimestampStr,
    this.uAc1,
    this.iAc1,
    this.uAc2,
    this.iAc2,
    this.uAc3,
    this.iAc3,
    this.uPv1,
    this.iPv1,
    this.uPv2,
    this.iPv2,
    this.uDc1,
    this.iDc1,
    this.fac,
    this.facStr,
    this.ratedPower,
    this.fullHour,
    this.totalFullHour,
    this.collectorSn,
    this.stateExceptionFlag,
    this.productModel,
    this.batteryCapacitySoc,
    this.batteryPower,
    this.batteryTotalChargeEnergy,
    this.batteryTotalDischargeEnergy,
  });

  bool get isOnline => state == 1;
  bool get isAlarm => state == 3;

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

  /// pac is already in kW according to API doc
  double get pacKw => pac ?? 0;

  /// Display helpers
  String get pacDisplay =>
      '${pac?.toStringAsFixed(2) ?? "0"} ${pacStr ?? "kW"}';
  String get eTodayDisplay =>
      '${eToday?.toStringAsFixed(1) ?? "0"} ${eTodayStr ?? "kWh"}';
  String get eTotalDisplay =>
      '${eTotal?.toStringAsFixed(1) ?? "0"} ${eTotalStr ?? "kWh"}';

  factory Inverter.fromJson(Map<String, dynamic> json) {
    return Inverter(
      id: (json['id'] ?? '').toString(),
      sn: (json['sn'] ?? json['inverterSn'] ?? '').toString(),
      inverterName:
          json['name']?.toString() ?? json['inverterName']?.toString(),
      stationId: json['stationId']?.toString(),
      stationName: json['stationName']?.toString(),
      pac: _parseDouble(json['pac']),
      pacStr: json['pacStr']?.toString(),
      power: _parseDouble(json['power']),
      powerStr: json['powerStr']?.toString(),
      eToday: _parseDouble(json['etoday'] ?? json['eToday']),
      eTodayStr: (json['etodayStr'] ?? json['eTodayStr'])?.toString(),
      eMonth: _parseDouble(json['eMonth']),
      eMonthStr: json['eMonthStr']?.toString(),
      eYear: _parseDouble(json['eYear']),
      eYearStr: json['eYearStr']?.toString(),
      eTotal: _parseDouble(json['etotal'] ?? json['eTotal']),
      eTotalStr: (json['etotalStr'] ?? json['eTotalStr'])?.toString(),
      eTotal1: _parseDouble(json['etotal1'] ?? json['eTotal1']),
      state: _parseInt(json['state']),
      dataTimestamp: _parseInt(json['dataTimestamp']),
      dataTimestampStr: json['dataTimestampStr']?.toString(),
      uAc1: _parseDouble(json['uAc1']),
      iAc1: _parseDouble(json['iAc1']),
      uAc2: _parseDouble(json['uAc2']),
      iAc2: _parseDouble(json['iAc2']),
      uAc3: _parseDouble(json['uAc3']),
      iAc3: _parseDouble(json['iAc3']),
      uPv1: _parseDouble(json['uPv1']),
      iPv1: _parseDouble(json['iPv1']),
      uPv2: _parseDouble(json['uPv2']),
      iPv2: _parseDouble(json['iPv2']),
      uDc1: _parseDouble(json['uDc1']),
      iDc1: _parseDouble(json['iDc1']),
      fac: _parseDouble(json['fac']),
      facStr: json['facStr']?.toString(),
      ratedPower: _parseDouble(json['power']),
      fullHour: _parseDouble(json['fullHour']),
      totalFullHour: _parseDouble(json['totalFullHour']),
      collectorSn: json['collectorSn']?.toString(),
      stateExceptionFlag: _parseInt(json['stateExceptionFlag']),
      productModel: json['productModel']?.toString(),
      batteryCapacitySoc: _parseDouble(
        json['batteryCapacitySoc'] ?? json['soc'],
      ),
      batteryPower: _parseDouble(json['batteryPower']),
      batteryTotalChargeEnergy: _parseDouble(json['batteryTotalChargeEnergy']),
      batteryTotalDischargeEnergy: _parseDouble(
        json['batteryTotalDischargeEnergy'],
      ),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
