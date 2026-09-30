import 'dart:async';

import 'package:flutter/material.dart';

import '../models/growatt/growatt_plant.dart';
import '../models/huawei/huawei_plant.dart';
import '../models/station.dart';
import '../screens/growatt_plant_detail_screen.dart';
import '../screens/huawei_plant_detail_screen.dart';
import '../screens/plant_detail_screen.dart';
import 'auth_service.dart';
import 'push_notification_service.dart';

class PushNotificationNavigationService {
  PushNotificationNavigationService._();

  static final navigatorKey = GlobalKey<NavigatorState>();
  static bool _authenticatedShellReady = false;

  static void initialize() {
    PushNotificationService.registerNavigationHandler(_openRequest);
  }

  static void markAuthenticatedShellReady() {
    _authenticatedShellReady = true;
    PushNotificationService.resumePendingNavigation();
  }

  static void markAuthenticationRequired() {
    _authenticatedShellReady = false;
  }

  static bool open(PushNavigationRequest request) => _openRequest(request);

  static bool _openRequest(PushNavigationRequest request) {
    final navigator = navigatorKey.currentState;
    if (!_authenticatedShellReady ||
        !AuthService.isLoggedIn ||
        navigator == null) {
      return false;
    }

    final destination = _destinationFor(request);
    scheduleMicrotask(() {
      navigator.push(
        MaterialPageRoute<void>(
          settings: RouteSettings(
            name: '/notification/${request.source}/${request.plantCode}',
            arguments: request,
          ),
          builder: (_) => destination,
        ),
      );
    });
    return true;
  }

  static Widget _destinationFor(PushNavigationRequest request) {
    final isOnline = request.status == 'online';
    final isIssue = request.showAlarm;

    switch (request.source) {
      case 'huawei':
        return HuaweiPlantDetailScreen(
          plant: HuaweiPlant(
            source: 'huawei',
            plantName: request.plantName,
            plantCode: request.plantCode,
            capacity: 0,
            currentPower: 0,
            dailyEnergy: 0,
            monthlyEnergy: 0,
            yearlyEnergy: 0,
            totalEnergy: 0,
            status: isOnline ? 'online' : (isIssue ? 'warning' : 'unknown'),
            address: '',
            latitude: '',
            longitude: '',
          ),
        );
      case 'growatt':
        return GrowattPlantDetailScreen(
          plant: GrowattPlant(
            source: 'growatt',
            plantName: request.plantName,
            plantCode: request.plantCode,
            capacity: 0,
            currentPower: 0,
            dailyEnergy: 0,
            monthlyEnergy: 0,
            yearlyEnergy: 0,
            totalEnergy: 0,
            status: isOnline ? 'online' : (isIssue ? 'warning' : 'unknown'),
            address: '',
            latitude: '',
            longitude: '',
          ),
        );
      default:
        return PlantDetailScreen(
          station: Station(
            id: request.plantCode,
            stationName: request.plantName,
            capacity: 0,
            state: isOnline ? 1 : (isIssue ? 3 : 2),
          ),
          showAlarmsInitially: request.showAlarm,
        );
    }
  }
}
