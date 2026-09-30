class Incident {
  final String id;
  final String entityType;
  final String entityId;
  final String entityName;
  final String source;
  final String plantCode;
  final String plantName;
  final String status;
  final String priority;
  final String priorityLabel;
  final int slaMinutes;
  final DateTime startedAt;
  final DateTime slaDueAt;
  final DateTime? resolvedAt;
  final int durationSeconds;
  final bool slaBreached;
  final bool isOpen;
  final String address;
  final double? latitude;
  final double? longitude;

  const Incident({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.source,
    required this.plantCode,
    required this.plantName,
    required this.status,
    required this.priority,
    required this.priorityLabel,
    required this.slaMinutes,
    required this.startedAt,
    required this.slaDueAt,
    required this.resolvedAt,
    required this.durationSeconds,
    required this.slaBreached,
    required this.isOpen,
    required this.address,
    this.latitude,
    this.longitude,
  });

  bool get hasLocation =>
      (latitude != null && longitude != null) || address.trim().isNotEmpty;

  Duration get duration => Duration(seconds: durationSeconds);

  String get durationLabel {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '$hours jam $minutes menit';
    return '${duration.inMinutes.clamp(1, 999999)} menit';
  }

  factory Incident.fromJson(Map<String, dynamic> json) {
    DateTime date(String key) =>
        DateTime.tryParse(json[key]?.toString() ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);

    DateTime? nullableDate(String key) {
      final value = json[key]?.toString();
      return value == null || value.isEmpty
          ? null
          : DateTime.tryParse(value)?.toLocal();
    }

    return Incident(
      id: json['id']?.toString() ?? '',
      entityType: json['entityType']?.toString() ?? 'plant',
      entityId: json['entityId']?.toString() ?? '',
      entityName: json['entityName']?.toString() ?? 'Unknown device',
      source: json['source']?.toString() ?? 'unknown',
      plantCode: json['plantCode']?.toString() ?? '',
      plantName: json['plantName']?.toString() ?? 'Unknown plant',
      status: json['status']?.toString() ?? 'unknown',
      priority: json['priority']?.toString() ?? 'P3',
      priorityLabel: json['priorityLabel']?.toString() ?? 'Medium',
      slaMinutes: _integer(json['slaMinutes']),
      startedAt: date('startedAt'),
      slaDueAt: date('slaDueAt'),
      resolvedAt: nullableDate('resolvedAt'),
      durationSeconds: _integer(json['durationSeconds']),
      slaBreached: json['slaBreached'] == true,
      isOpen: json['isOpen'] == true,
      address: json['address']?.toString() ?? '',
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
    );
  }

  static int _integer(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
