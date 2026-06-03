class HuaweiAlarm {
  final String alarmId;
  final String alarmName;
  final String severity;
  final int severityLevel;
  final String plantName;
  final String plantCode;
  final String deviceType;
  final String deviceName;
  final String sn;
  final String status;
  final String alarmCause;
  final String repairSuggestion;
  final String occurrenceTime;

  const HuaweiAlarm({
    required this.alarmId,
    required this.alarmName,
    required this.severity,
    required this.severityLevel,
    required this.plantName,
    required this.plantCode,
    required this.deviceType,
    required this.deviceName,
    required this.sn,
    required this.status,
    required this.alarmCause,
    required this.repairSuggestion,
    required this.occurrenceTime,
  });

  factory HuaweiAlarm.fromJson(Map<String, dynamic> json) {
    return HuaweiAlarm(
      alarmId: _text(json['alarmId']),
      alarmName: _text(json['alarmName'], fallback: 'Unknown alarm'),
      severity: _text(json['severity'], fallback: 'unknown'),
      severityLevel: _int(json['severityLevel']),
      plantName: _text(json['plantName']),
      plantCode: _text(json['plantCode']),
      deviceType: _text(json['deviceType']),
      deviceName: _text(json['deviceName']),
      sn: _text(json['sn']),
      status: _text(json['status']),
      alarmCause: _text(json['alarmCause']),
      repairSuggestion: _text(json['repairSuggestion']),
      occurrenceTime: _text(json['occurrenceTime']),
    );
  }

  static String _text(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
