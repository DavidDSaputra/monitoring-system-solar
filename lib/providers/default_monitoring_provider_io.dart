import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'backend_monitoring_provider.dart';
import 'monitoring_provider.dart';
import 'solis_monitoring_provider.dart';

MonitoringProvider createDefaultMonitoringProvider() {
  final useNativeSolis =
      dotenv.env['MONITORING_USE_NATIVE_SOLIS']?.toLowerCase() == 'true';
  final hasNativeSolisCredentials =
      (dotenv.env['SOLIS_API_KEY']?.trim().isNotEmpty ?? false) &&
      (dotenv.env['SOLIS_API_SECRET']?.trim().isNotEmpty ?? false);

  if (useNativeSolis && hasNativeSolisCredentials) {
    return SolisMonitoringProvider();
  }

  return BackendMonitoringProvider();
}
