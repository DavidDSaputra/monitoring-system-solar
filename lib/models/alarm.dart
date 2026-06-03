class Alarm {
  final String id;
  final String alarmDeviceSn;
  final String? stationId;
  final String? stationName;
  final String? alarmMsg;
  final String? alarmName;
  final int? alarmLevel; // 1: prompt, 2: warning, 3: severe
  final int? alarmStatus; // 0: unrecovered, 1: recovered
  final int? alarmBeginTime;
  final String? alarmBeginTimeStr;
  final int? alarmRecoverTime;
  final String? alarmRecoverTimeStr;

  Alarm({
    required this.id,
    required this.alarmDeviceSn,
    this.stationId,
    this.stationName,
    this.alarmMsg,
    this.alarmName,
    this.alarmLevel,
    this.alarmStatus,
    this.alarmBeginTime,
    this.alarmBeginTimeStr,
    this.alarmRecoverTime,
    this.alarmRecoverTimeStr,
  });

  bool get isRecovered => alarmStatus == 1;

  String get levelText {
    switch (alarmLevel) {
      case 1:
        return 'Prompt';
      case 2:
        return 'Warning';
      case 3:
        return 'Severe';
      default:
        return 'Unknown';
    }
  }

  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: (json['id'] ?? '').toString(),
      alarmDeviceSn: (json['alarmDeviceSn'] ?? '').toString(),
      stationId: json['stationId']?.toString(),
      stationName: json['stationName']?.toString(),
      alarmMsg: json['alarmMsg']?.toString(),
      alarmName: json['alarmName']?.toString(),
      alarmLevel: _parseInt(json['alarmLevel']),
      alarmStatus: _parseInt(json['alarmStatus']),
      alarmBeginTime: _parseInt(json['alarmBeginTime']),
      alarmBeginTimeStr: json['alarmBeginTimeStr']?.toString(),
      alarmRecoverTime: _parseInt(json['alarmRecoverTime']),
      alarmRecoverTimeStr: json['alarmRecoverTimeStr']?.toString(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
