// ignore_for_file: constant_identifier_names

import 'package:flutter_dotenv/flutter_dotenv.dart';

final String GOOGLE_MAPS_API_KEY = (dotenv.env['GOOGLE_MAPS_API_KEY'] != null &&
        dotenv.env['GOOGLE_MAPS_API_KEY']!.trim().isNotEmpty &&
        dotenv.env['GOOGLE_MAPS_API_KEY'] != 'your_google_maps_api_key_here')
    ? dotenv.env['GOOGLE_MAPS_API_KEY']!.trim()
    : 'AIzaSyBC-9h-ad-8t_40wZCkUeB1TPhQUvfGelM';
final int TARGET_LANE_LIMIT = int.tryParse(dotenv.env['TARGET_LANE_LIMIT'] ?? '4') ?? 4;
