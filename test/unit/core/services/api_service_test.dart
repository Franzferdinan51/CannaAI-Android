import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:canna_ai/core/services/api_service.dart';
import 'package:canna_ai/core/models/sensor_data.dart';
import 'package:canna_ai/core/models/plant_analysis.dart';

import 'api_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('ApiService Tests', () {
    late ApiService apiService;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      apiService = ApiService(client: mockClient);
    });

    group('fetchSensorData', () {
      test('returns sensor data when the call completes successfully', () async {
        // Arrange
        const roomId = 'room_1';
        when(mockClient.get(
          Uri.parse('https://api.cannaai.com/sensors/$roomId'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          '{"temperature": 25.5, "humidity": 65.2, "ph": 6.8, "ec": 1.6}',
          200,
        ));

        // Act
        final result = await apiService.fetchSensorData(roomId);

        // Assert
        expect(result, isA<SensorData>());
        expect(result.temperature, equals(25.5));
        expect(result.humidity, equals(65.2));
        expect(result.ph, equals(6.8));
        expect(result.ec, equals(1.6));
        verify(mockClient.get(
          Uri.parse('https://api.cannaai.com/sensors/$roomId'),
          headers: anyNamed('headers'),
        )).called(1);
      });

      test('throws exception when the call completes with an error', () async {
        // Arrange
        const roomId = 'room_1';
        when(mockClient.get(
          Uri.parse('https://api.cannaai.com/sensors/$roomId'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response('Not Found', 404));

        // Act & Assert
        expect(
          () async => await apiService.fetchSensorData(roomId),
          throwsA(isA<Exception>()),
        );
      });

      test('handles timeout correctly', () async {
        // Arrange
        const roomId = 'room_1';
        when(mockClient.get(
          Uri.parse('https://api.cannaai.com/sensors/$roomId'),
          headers: anyNamed('headers'),
        )).thenThrow(http.ClientException('Connection timeout'));

        // Act & Assert
        expect(
          () async => await apiService.fetchSensorData(roomId),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('analyzePlantHealth', () {
      test('returns plant analysis when image upload succeeds', () async {
        // Arrange
        final imageBytes = List<int>.filled(1024, 0);
        final symptoms = ['yellowing', 'spotting'];
        final strain = 'Blue Dream';

        when(mockClient.post(
          Uri.parse('https://api.cannaai.com/analyze'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '{"confidence": 0.95, "health_status": "healthy", "recommendations": ["Increase watering"], "predicted_yield": 0.85}',
          200,
        ));

        // Act
        final result = await apiService.analyzePlantHealth(
          imageBytes,
          symptoms,
          strain,
        );

        // Assert
        expect(result, isA<PlantAnalysis>());
        expect(result.confidence, equals(0.95));
        expect(result.healthStatus, equals('healthy'));
        expect(result.recommendations, contains('Increase watering'));
        expect(result.predictedYield, equals(0.85));
      });

      test('handles invalid image format', () async {
        // Arrange
        final imageBytes = []; // Empty image data
        final symptoms = ['yellowing'];
        final strain = 'Blue Dream';

        when(mockClient.post(
          Uri.parse('https://api.cannaai.com/analyze'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '{"error": "Invalid image format"}',
          400,
        ));

        // Act & Assert
        expect(
          () async => await apiService.analyzePlantHealth(
            imageBytes,
            symptoms,
            strain,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('updateAutomationSettings', () {
      test('successfully updates automation settings', () async {
        // Arrange
        const roomId = 'room_1';
        final settings = {
          'watering_enabled': true,
          'watering_threshold': 30.0,
          'lighting_schedule': {'on': '06:00', 'off': '22:00'},
        };

        when(mockClient.put(
          Uri.parse('https://api.cannaai.com/automation/$roomId'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '{"success": true, "message": "Settings updated"}',
          200,
        ));

        // Act
        final result = await apiService.updateAutomationSettings(roomId, settings);

        // Assert
        expect(result.success, isTrue);
        expect(result.message, equals('Settings updated'));
        verify(mockClient.put(
          Uri.parse('https://api.cannaai.com/automation/$roomId'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).called(1);
      });
    });

    group('authentication', () {
      test('handles successful authentication', () async {
        // Arrange
        const email = 'user@example.com';
        const password = 'password123';

        when(mockClient.post(
          Uri.parse('https://api.cannaai.com/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '{"token": "fake_token", "user_id": "123", "expires_in": 3600}',
          200,
        ));

        // Act
        final result = await apiService.authenticate(email, password);

        // Assert
        expect(result.token, equals('fake_token'));
        expect(result.userId, equals('123'));
        expect(result.expiresIn, equals(3600));
      });

      test('handles failed authentication', () async {
        // Arrange
        const email = 'user@example.com';
        const password = 'wrongpassword';

        when(mockClient.post(
          Uri.parse('https://api.cannaai.com/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          '{"error": "Invalid credentials"}',
          401,
        ));

        // Act & Assert
        expect(
          () async => await apiService.authenticate(email, password),
          throwsA(isA<AuthenticationException>()),
        );
      });
    });

    group('rate limiting', () {
      test('respects rate limiting headers', () async {
        // Arrange
        const roomId = 'room_1';
        when(mockClient.get(
          Uri.parse('https://api.cannaai.com/sensors/$roomId'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          '{"temperature": 25.5}',
          200,
          headers: {
            'x-ratelimit-remaining': '9',
            'x-ratelimit-reset': '1640995200',
          },
        ));

        // Act
        await apiService.fetchSensorData(roomId);

        // Assert
        expect(apiService.rateLimitRemaining, equals(9));
        expect(apiService.rateLimitReset, equals(1640995200));
      });

      test('handles rate limiting exceeded', () async {
        // Arrange
        const roomId = 'room_1';
        when(mockClient.get(
          Uri.parse('https://api.cannaai.com/sensors/$roomId'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          '{"error": "Rate limit exceeded"}',
          429,
          headers: {
            'retry-after': '60',
          },
        ));

        // Act & Assert
        expect(
          () async => await apiService.fetchSensorData(roomId),
          throwsA(isA<RateLimitException>()),
        );
      });
    });

    group('caching', () {
      test('caches successful responses', () async {
        // Arrange
        const roomId = 'room_1';
        when(mockClient.get(
          Uri.parse('https://api.cannaai.com/sensors/$roomId'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          '{"temperature": 25.5, "cache-control": "max-age=300"}',
          200,
          headers: {'cache-control': 'max-age=300'},
        ));

        // Act
        final result1 = await apiService.fetchSensorData(roomId);
        final result2 = await apiService.fetchSensorData(roomId);

        // Assert
        expect(result1.temperature, equals(result2.temperature));
        verify(mockClient.get(
          Uri.parse('https://api.cannaai.com/sensors/$roomId'),
          headers: anyNamed('headers'),
        )).called(1); // Only called once due to caching
      });
    });
  });
}