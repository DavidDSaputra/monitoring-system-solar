import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> loadEnvironment() async {
  final localEnv = File('.env');
  if (await localEnv.exists()) {
    dotenv.loadFromString(envString: await localEnv.readAsString());
    return;
  }

  await dotenv.load(fileName: 'assets/config/app.env');
}
