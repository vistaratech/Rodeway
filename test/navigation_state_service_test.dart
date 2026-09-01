import 'package:cleadr/src/services/navigation_state_service.dart';
import 'package:cleadr/src/util/place.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Place Serialization', () {
    test('toJson and fromJson serialize and deserialize correctly', () {
      final place = Place(
        place_id: 'test_id_123',
        name: 'Central Station',
        formatted_address: '123 Main Street',
        lat: 3.1390,
        lng: 101.6869,
        distanceStr: '5.2 km',
        durationStr: '12 mins',
        duration: 720,
        startTime: DateTime(2026, 7, 28, 10, 0),
        endTime: DateTime(2026, 7, 28, 10, 12),
      );

      final jsonMap = place.toJson();
      final restored = Place.fromJson(jsonMap);

      expect(restored.place_id, 'test_id_123');
      expect(restored.name, 'Central Station');
      expect(restored.formatted_address, '123 Main Street');
      expect(restored.lat, 3.1390);
      expect(restored.lng, 101.6869);
      expect(restored.distanceStr, '5.2 km');
      expect(restored.durationStr, '12 mins');
      expect(restored.duration, 720);
    });
  });

  group('NavigationStateService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial state is empty', () async {
      final service = NavigationStateService.instance;
      await service.init();

      expect(service.hasActiveDestination, isFalse);
      expect(service.activePlace, isNull);
      expect(service.destinationLocation, isNull);
      expect(service.isRoutePreview, isFalse);
      expect(service.isNavigating, isFalse);
    });

    test('setDestination persists and updates state', () async {
      final service = NavigationStateService.instance;
      await service.init();

      final place = Place(
        place_id: 'p1',
        name: 'Kuala Lumpur City Centre',
        formatted_address: 'KLCC, Malaysia',
        lat: 3.1578,
        lng: 101.7118,
      );
      const target = LatLng(latitude: 3.1578, longitude: 101.7118);

      await service.setDestination(place, target, isRoutePreview: true);

      expect(service.hasActiveDestination, isTrue);
      expect(service.activePlace?.name, 'Kuala Lumpur City Centre');
      expect(service.destinationLocation?.latitude, 3.1578);
      expect(service.destinationLocation?.longitude, 101.7118);
      expect(service.isRoutePreview, isTrue);
    });

    test('clearDestination resets state and storage', () async {
      final service = NavigationStateService.instance;
      await service.init();

      final place = Place(name: 'Test Place', lat: 1.0, lng: 1.0);
      await service.setDestination(place, const LatLng(latitude: 1.0, longitude: 1.0));
      expect(service.hasActiveDestination, isTrue);

      await service.clearDestination();
      expect(service.hasActiveDestination, isFalse);
      expect(service.activePlace, isNull);
      expect(service.destinationLocation, isNull);
    });
  });
}
