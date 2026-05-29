class AppConstants {
  AppConstants._();

  // SolisCloud API
  static const String baseUrl = 'https://www.soliscloud.com:13333';
  static const String defaultProxyUrl = 'api/solis_proxy.php';
  static const String defaultMonitoringApiBaseUrl = 'api';

  // API Endpoints - Plant
  static const String userStationList = '/v1/api/userStationList';
  static const String stationDetail = '/v1/api/stationDetail';
  static const String stationDay = '/v1/api/stationDay';
  static const String stationMonth = '/v1/api/stationMonth';
  static const String stationYear = '/v1/api/stationYear';
  static const String stationDayEnergyList = '/v1/api/stationDayEnergyList';

  // API Endpoints - Inverter
  static const String inverterList = '/v1/api/inverterList';
  static const String inverterDetail = '/v1/api/inverterDetail';
  static const String inverterDay = '/v1/api/inverterDay';

  // API Endpoints - Collector / Datalogger
  static const String collectorList = '/v1/api/collectorList';
  static const String collectorDetail = '/v1/api/collectorDetail';

  // API Endpoints - Battery / EPM
  static const String epmList = '/v1/api/epmList';
  static const String epmDetail = '/v1/api/epmDetail';

  // API Endpoints - Alarm
  static const String alarmList = '/v1/api/alarmList';

  // Rate Limiting
  static const int maxRequestsPerWindow = 3;
  static const Duration requestWindow = Duration(seconds: 5);

  // App Info
  static const String appName = 'JARWINN Monitoring';
  static const String appTagline = 'Renewable Energy Towards Brighter Future';
  static const String appVersion = '1.0.0';
}
