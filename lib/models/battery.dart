import 'inverter.dart';

/// Battery / EPM model from /v1/api/epmList
class Battery {
  final String id;
  final String sn;
  final String? batteryName;
  final String? stationId;
  final String? stationName;
  final int? state; // 1=online, 2=offline, 3=alarm
  final double? batteryPower;
  final String? batteryPowerStr;
  final double? batteryCapacitySoc; // SOC %
  final String? batteryCapacitySocStr;
  final double? batteryHealthSoh;
  final String? batteryHealthSohStr;
  final double? batteryTodayChargeEnergy;
  final String? batteryTodayChargeEnergyStr;
  final double? batteryTodayDischargeEnergy;
  final String? batteryTodayDischargeEnergyStr;
  final double? batteryTotalChargeEnergy;
  final String? batteryTotalChargeEnergyStr;
  final double? batteryTotalDischargeEnergy;
  final String? batteryTotalDischargeEnergyStr;
  final int? dataTimestamp;
  final String? dataTimestampStr;
  final double? gridPurchasedTodayEnergy;
  final double? gridSellTodayEnergy;
  final double? homeLoadTodayEnergy;
  final String? homeLoadTodayEnergyStr;

  Battery({
    required this.id,
    required this.sn,
    this.batteryName,
    this.stationId,
    this.stationName,
    this.state,
    this.batteryPower,
    this.batteryPowerStr,
    this.batteryCapacitySoc,
    this.batteryCapacitySocStr,
    this.batteryHealthSoh,
    this.batteryHealthSohStr,
    this.batteryTodayChargeEnergy,
    this.batteryTodayChargeEnergyStr,
    this.batteryTodayDischargeEnergy,
    this.batteryTodayDischargeEnergyStr,
    this.batteryTotalChargeEnergy,
    this.batteryTotalChargeEnergyStr,
    this.batteryTotalDischargeEnergy,
    this.batteryTotalDischargeEnergyStr,
    this.dataTimestamp,
    this.dataTimestampStr,
    this.gridPurchasedTodayEnergy,
    this.gridSellTodayEnergy,
    this.homeLoadTodayEnergy,
    this.homeLoadTodayEnergyStr,
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

  String get socDisplay => '${batteryCapacitySoc?.toStringAsFixed(0) ?? "-"}%';

  factory Battery.fromJson(Map<String, dynamic> json) {
    return Battery(
      id: (json['id'] ?? '').toString(),
      sn: (json['sn'] ?? json['inverterSn'] ?? '').toString(),
      batteryName: json['name']?.toString() ?? json['batteryName']?.toString(),
      stationId: json['stationId']?.toString(),
      stationName: json['stationName']?.toString(),
      state: _parseInt(json['state']),
      batteryPower: _p(json['batteryPower'] ?? json['pEpmTotal']),
      batteryPowerStr: json['batteryPowerStr']?.toString(),
      batteryCapacitySoc: _p(json['batteryCapacitySoc']),
      batteryCapacitySocStr: json['batteryCapacitySocStr']?.toString(),
      batteryHealthSoh: _p(json['batteryHealthSoh']),
      batteryHealthSohStr: json['batteryHealthSohStr']?.toString(),
      batteryTodayChargeEnergy: _p(json['batteryTodayChargeEnergy']),
      batteryTodayChargeEnergyStr: json['batteryTodayChargeEnergyStr']
          ?.toString(),
      batteryTodayDischargeEnergy: _p(json['batteryTodayDischargeEnergy']),
      batteryTodayDischargeEnergyStr: json['batteryTodayDischargeEnergyStr']
          ?.toString(),
      batteryTotalChargeEnergy: _p(json['batteryTotalChargeEnergy']),
      batteryTotalChargeEnergyStr: json['batteryTotalChargeEnergyStr']
          ?.toString(),
      batteryTotalDischargeEnergy: _p(json['batteryTotalDischargeEnergy']),
      batteryTotalDischargeEnergyStr: json['batteryTotalDischargeEnergyStr']
          ?.toString(),
      dataTimestamp: _parseInt(json['dataTimestamp']),
      dataTimestampStr: json['dataTimestampStr']?.toString(),
      gridPurchasedTodayEnergy: _p(json['gridPurchasedTodayEnergy']),
      gridSellTodayEnergy: _p(json['gridSellTodayEnergy']),
      homeLoadTodayEnergy: _p(json['homeLoadTodayEnergy']),
      homeLoadTodayEnergyStr: json['homeLoadTodayEnergyStr']?.toString(),
    );
  }

  static double? _p(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory Battery.fromInverter(Inverter inverter) {
    return Battery(
      id: inverter.id,
      sn: inverter.sn,
      batteryName: inverter.inverterName != null
          ? '${inverter.inverterName} (Battery)'
          : 'Hybrid Battery',
      stationId: inverter.stationId,
      stationName: inverter.stationName,
      state: inverter.state,
      batteryPower:
          inverter.batteryPower ??
          inverter.pac, // Fallback to inverter power if missing
      batteryCapacitySoc: inverter.batteryCapacitySoc,
      batteryTotalChargeEnergy: inverter.batteryTotalChargeEnergy,
      batteryTotalDischargeEnergy: inverter.batteryTotalDischargeEnergy,
      dataTimestamp: inverter.dataTimestamp,
      dataTimestampStr: inverter.dataTimestampStr,
    );
  }
}
