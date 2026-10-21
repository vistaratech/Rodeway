// ignore_for_file: constant_identifier_names

import 'package:flutter_dotenv/flutter_dotenv.dart';

final String GOOGLE_MAPS_API_KEY = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
final int TARGET_LANE_LIMIT = int.tryParse(dotenv.env['TARGET_LANE_LIMIT'] ?? '4') ?? 4;
