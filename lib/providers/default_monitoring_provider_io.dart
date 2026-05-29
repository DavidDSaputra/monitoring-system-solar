import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'backend_monitoring_provider.dart';
import 'monitoring_provider.dart';
import 'solis_monitoring_provider.dart';

MonitoringProvider createDefaultMonitoringProvider() {
  final hasNativeSolisCredentials =
      (dotenv.env['SOLIS_API_KEY']?.trim().isNotEmpty ?? false) &&
      (dotenv.env['SOLIS_API_SECRET']?.trim().isNotEmpty ?? false);

  if (!hasNativeSolisCredentials) {
    return BackendMonitoringProvider();
  }

  return SolisMonitoringProvider();
}
