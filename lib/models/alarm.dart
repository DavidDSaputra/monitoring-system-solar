class Alarm {
  final String id;
  final String alarmDeviceSn;
  final String? alarmDeviceId;
  final String? alarmDeviceType;
  final String? stationId;
  final String? stationName;
  final String? alarmMsg;
  final String? alarmName;
  final String? alarmCode;
  final String? alarmLong;
  final String? advice;
  final String? model;
  final String? machine;
  final String? countryStr;
  final String? regionStr;
  final String? cityStr;
  final String? countyStr;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int? alarmLevel; // 1: prompt, 2: warning, 3: severe
  final int? alarmStatus; // 0: unrecovered, 1: recovered
  final int? alarmBeginTime;
  final String? alarmBeginTimeStr;
  final int? alarmEndTime;
  final String? alarmEndTimeStr;
  final int? alarmRecoverTime;
  final String? alarmRecoverTimeStr;

  Alarm({
    required this.id,
    required this.alarmDeviceSn,
    this.alarmDeviceId,
    this.alarmDeviceType,
    this.stationId,
    this.stationName,
    this.alarmMsg,
    this.alarmName,
    this.alarmCode,
    this.alarmLong,
    this.advice,
    this.model,
    this.machine,
    this.countryStr,
    this.regionStr,
    this.cityStr,
    this.countyStr,
    this.address,
    this.latitude,
    this.longitude,
    this.alarmLevel,
    this.alarmStatus,
    this.alarmBeginTime,
    this.alarmBeginTimeStr,
    this.alarmEndTime,
    this.alarmEndTimeStr,
    this.alarmRecoverTime,
    this.alarmRecoverTimeStr,
  });

  bool get isRecovered => alarmStatus == 1;

  String get levelText {
    switch (alarmLevel) {
      case 1:
        return 'Info';
      case 2:
        return 'Warning';
      case 3:
        return 'Severe';
      default:
        return 'Unknown';
    }
  }

  String get statusText => isRecovered ? 'Recovered' : 'Active';

  String get title {
    final message = alarmMsg?.trim();
    if (message != null && message.isNotEmpty) return message;
    final name = alarmName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Unknown Alarm';
  }

  String get deviceTypeText {
    final value = alarmDeviceType?.trim();
    switch (value) {
      case '1':
        return 'Plant';
      case '2':
        return 'Datalogger';
      case '3':
        return 'Inverter';
      case '4':
        return 'Battery';
      default:
        return alarmDeviceSn.isNotEmpty ? 'Inverter' : '-';
    }
  }

  String get plantAddress {
    final parts = [
      countyStr,
      cityStr,
      regionStr,
      countryStr,
    ].whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty);
    final areaAddress = parts.join(', ');
    final fullAddress = address?.trim();
    if (fullAddress != null && fullAddress.isNotEmpty) return fullAddress;
    return areaAddress;
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  String get durationText {
    final begin = alarmBeginTime;
    final end = alarmRecoverTime ?? alarmEndTime;
    if (begin != null && end != null && end >= begin) {
      return _formatDuration(Duration(milliseconds: end - begin));
    }

    final raw = int.tryParse(alarmLong ?? '');
    if (raw != null && raw > 0) {
      return _formatDuration(Duration(milliseconds: raw));
    }

    return isRecovered ? '-' : '< 1m';
  }

  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: (json['id'] ?? '').toString(),
      alarmDeviceSn: (json['alarmDeviceSn'] ?? '').toString(),
      alarmDeviceId: json['alarmDeviceId']?.toString(),
      alarmDeviceType: json['alarmDeviceType']?.toString(),
      stationId: json['stationId']?.toString(),
      stationName: json['stationName']?.toString(),
      alarmMsg: json['alarmMsg']?.toString(),
      alarmName: json['alarmName']?.toString(),
      alarmCode: json['alarmCode']?.toString(),
      alarmLong: json['alarmLong']?.toString(),
      advice: json['advice']?.toString(),
      model: json['model']?.toString(),
      machine: json['machine']?.toString(),
      countryStr: json['countryStr']?.toString(),
      regionStr: json['regionStr']?.toString(),
      cityStr: json['cityStr']?.toString(),
      countyStr: json['countyStr']?.toString(),
      address: _pickText(json, const ['addr', 'addrOrigin', 'address']),
      latitude: _parseDouble(
        _pick(json, const ['latitude', 'lat', 'mapLat', 'stationLat']),
      ),
      longitude: _parseDouble(
        _pick(json, const ['longitude', 'lng', 'lon', 'mapLng', 'stationLng']),
      ),
      alarmLevel: _parseInt(json['alarmLevel']),
      alarmStatus: _parseInt(json['alarmStatus']),
      alarmBeginTime: _parseInt(json['alarmBeginTime']),
      alarmBeginTimeStr: json['alarmBeginTimeStr']?.toString(),
      alarmEndTime: _parseInt(json['alarmEndTime']),
      alarmEndTimeStr: json['alarmEndTimeStr']?.toString(),
      alarmRecoverTime: _parseInt(json['alarmRecoverTime']),
      alarmRecoverTimeStr: json['alarmRecoverTimeStr']?.toString(),
    );
  }

  static String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    }
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    if (duration.inMinutes > 0) return '${duration.inMinutes}m';
    return '< 1m';
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static dynamic _pick(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) return json[key];
    }
    return null;
  }

  static String? _pickText(Map<String, dynamic> json, List<String> keys) {
    final value = _pick(json, keys);
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
