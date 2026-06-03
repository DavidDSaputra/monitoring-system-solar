class GrowattPowerPoint {
  final String time;
  final double power;

  const GrowattPowerPoint({required this.time, required this.power});

  factory GrowattPowerPoint.fromJson(Map<String, dynamic> json) {
    return GrowattPowerPoint(
      time: json['time']?.toString() ?? '',
      power: _number(json['power']),
    );
  }

  static double _number(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
