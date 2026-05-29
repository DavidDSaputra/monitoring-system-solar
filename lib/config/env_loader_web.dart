import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> loadEnvironment() {
  return dotenv.load(fileName: 'assets/config/app.env');
}
