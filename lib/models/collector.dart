/// Collector / Datalogger model from /v1/api/collectorList
class Collector {
  final Map<String, dynamic> raw;
  final String id;
  final String sn;
  final String? collectorName;
  final String? stationId;
  final String? stationName;
  final int? state; // 1=online, 2=offline
  final int? dataTimestamp;
  final String? dataTimestampStr;
  final String? collectorType;
  final String? firmwareVersion;
  final String? ipAddress;
  final String? macAddress;
  final String? ssid;
  final String? lanApi;
  final String? simFlowState;
  final int? inverterCount;
  final int? signalStrength;
  final String? signalStrengthStr;

  Collector({
    required this.raw,
    required this.id,
    required this.sn,
    this.collectorName,
    this.stationId,
    this.stationName,
    this.state,
    this.dataTimestamp,
    this.dataTimestampStr,
    this.collectorType,
    this.firmwareVersion,
    this.ipAddress,
    this.macAddress,
    this.ssid,
    this.lanApi,
    this.simFlowState,
    this.inverterCount,
    this.signalStrength,
    this.signalStrengthStr,
  });

  bool get isOnline => state == 1;
  String get statusText => isOnline ? 'Online' : 'Offline';

  factory Collector.fromJson(Map<String, dynamic> json) {
    final raw = Map<String, dynamic>.from(json);
    return Collector(
      raw: raw,
      id: (json['id'] ?? '').toString(),
      sn: (json['sn'] ?? json['collectorSn'] ?? '').toString(),
      collectorName:
          json['collectorName']?.toString() ?? json['name']?.toString(),
      stationId: json['stationId']?.toString(),
      stationName: json['stationName']?.toString(),
      state: _parseInt(json['state']),
      dataTimestamp: _parseInt(json['dataTimestamp']),
      dataTimestampStr: json['dataTimestampStr']?.toString(),
      collectorType:
          (json['collectorType'] ?? json['model'] ?? json['dataloggerModel'])
              ?.toString(),
      firmwareVersion:
          (json['firmwareVersion'] ?? json['softVersion'] ?? json['version'])
              ?.toString(),
      ipAddress: (json['ipAddress'] ?? json['ip'] ?? json['lanIp'])?.toString(),
      macAddress: _pickFirstString(raw, const [
        'mac',
        'macAddress',
        'macAddr',
        'wifiMac',
        'lanMac',
        'deviceMac',
      ]),
      ssid: _pickFirstString(raw, const [
        'ssid',
        'wifiSsid',
        'wifiName',
        'apSsid',
      ]),
      lanApi: _pickFirstString(raw, const [
        'lanApi',
        'lanApiUrl',
        'lanApiAddress',
        'lanApiHost',
      ]),
      simFlowState: json['simFlowState']?.toString(),
      inverterCount: _parseInt(json['inverterCount']),
      signalStrength: _parseInt(
        json['signalStrength'] ?? json['rssiLevel'] ?? json['rssi'],
      ),
      signalStrengthStr: json['signalStrengthStr']?.toString(),
    );
  }

  static String? _pickFirstString(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
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
