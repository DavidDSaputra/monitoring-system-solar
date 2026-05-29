class EnergyData {
  final String time; // Time label (e.g., "06:00", "12:00")
  final double? power; // Power in kW at this time point
  final double? energy; // Cumulative energy in kWh at this point
  final int? timeStamp;

  EnergyData({required this.time, this.power, this.energy, this.timeStamp});

  factory EnergyData.fromJson(Map<String, dynamic> json) {
    return EnergyData(
      time: json['time']?.toString() ?? json['timeStr']?.toString() ?? '',
      power: _parseDouble(json['power'] ?? json['pac'] ?? json['pow']),
      energy: _parseDouble(json['energy'] ?? json['eToday'] ?? json['value']),
      timeStamp: json['timeStamp'] as int?,
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

class DayEnergyResponse {
  final List<EnergyData> dataPoints;
  final double? totalEnergy;
  final String? date;

  DayEnergyResponse({required this.dataPoints, this.totalEnergy, this.date});

  factory DayEnergyResponse.fromJson(Map<String, dynamic> json) {
    final List<EnergyData> points = [];

    // Handle different response formats
    if (json['data'] is List) {
      for (var item in json['data']) {
        points.add(EnergyData.fromJson(item));
      }
    } else if (json['records'] is List) {
      for (var item in json['records']) {
        points.add(EnergyData.fromJson(item));
      }
    }

    return DayEnergyResponse(
      dataPoints: points,
      totalEnergy: _parseDouble(json['totalEnergy']),
      date: json['date']?.toString(),
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
