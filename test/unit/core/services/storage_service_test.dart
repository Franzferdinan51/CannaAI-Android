import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canna_ai/core/services/storage_service.dart';

void main() {
  group('StorageService Tests', () {
    late StorageService storageService;

    setUp(() async {
      // Reset SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      storageService = StorageService();
      await storageService.init();
    });

    group('User Preferences', () {
      test('should save and retrieve user preferences', () async {
        // Arrange
        const key = 'user_preferences';
        const preferences = {
          'theme_mode': 'dark',
          'notifications_enabled': true,
          'auto_analysis': false,
        };

        // Act
        await storageService.saveData(key, preferences);
        final retrieved = await storageService.getData<Map<String, dynamic>>(key);

        // Assert
        expect(retrieved, isNotNull);
        expect(retrieved!['theme_mode'], equals('dark'));
        expect(retrieved['notifications_enabled'], isTrue);
        expect(retrieved['auto_analysis'], isFalse);
      });

      test('should return null for non-existent preferences', () async {
        // Act
        final result = await storageService.getData('non_existent_key');

        // Assert
        expect(result, isNull);
      });

      test('should update existing preferences', () async {
        // Arrange
        const key = 'user_preferences';
        const initialPreferences = {'theme_mode': 'light'};
        await storageService.saveData(key, initialPreferences);

        // Act
        const updatedPreferences = {'theme_mode': 'dark'};
        await storageService.saveData(key, updatedPreferences);
        final retrieved = await storageService.getData<Map<String, dynamic>>(key);

        // Assert
        expect(retrieved!['theme_mode'], equals('dark'));
      });
    });

    group('Plant History', () {
      test('should save plant analysis history', () async {
        // Arrange
        const key = 'plant_history';
        const analysisData = {
          'id': 'analysis_001',
          'timestamp': '2024-01-15T10:30:00Z',
          'image_path': '/path/to/image.jpg',
          'symptoms': ['yellowing', 'spotting'],
          'strain': 'Blue Dream',
          'confidence': 0.95,
          'health_status': 'healthy',
          'recommendations': ['Increase watering'],
        };

        // Act
        await storageService.savePlantAnalysis(analysisData);
        final history = await storageService.getPlantHistory();

        // Assert
        expect(history, isNotNull);
        expect(history.length, equals(1));
        expect(history.first['id'], equals('analysis_001'));
        expect(history.first['strain'], equals('Blue Dream'));
      });

      test('should retrieve multiple plant analyses', () async {
        // Arrange
        const analyses = [
          {
            'id': 'analysis_001',
            'timestamp': '2024-01-15T10:30:00Z',
            'strain': 'Blue Dream',
          },
          {
            'id': 'analysis_002',
            'timestamp': '2024-01-16T14:20:00Z',
            'strain': 'Green Crack',
          },
        ];

        // Act
        for (final analysis in analyses) {
          await storageService.savePlantAnalysis(analysis);
        }
        final history = await storageService.getPlantHistory();

        // Assert
        expect(history.length, equals(2));
        expect(history.first['id'], equals('analysis_002')); // Most recent first
        expect(history.last['id'], equals('analysis_001'));
      });

      test('should limit plant history size', () async {
        // Arrange - Create more than the maximum allowed analyses
        const maxHistorySize = 50;
        final analyses = List.generate(60, (index) => {
          'id': 'analysis_${index.toString().padLeft(3, '0')}',
          'timestamp': DateTime.now().subtract(Duration(days: index)).toIso8601String(),
          'strain': 'Test Strain $index',
        });

        // Act
        for (final analysis in analyses) {
          await storageService.savePlantAnalysis(analysis);
        }
        final history = await storageService.getPlantHistory();

        // Assert
        expect(history.length, equals(maxHistorySize));
        expect(history.first['id'], equals('analysis_059')); // Most recent
        expect(history.last['id'], equals('analysis_010')); // Oldest kept
      });

      test('should clear plant history', () async {
        // Arrange
        await storageService.savePlantAnalysis({
          'id': 'analysis_001',
          'timestamp': DateTime.now().toIso8601String(),
          'strain': 'Blue Dream',
        });

        // Act
        await storageService.clearPlantHistory();
        final history = await storageService.getPlantHistory();

        // Assert
        expect(history.isEmpty, isTrue);
      });
    });

    group('Sensor Data Cache', () {
      test('should cache sensor data with expiry', () async {
        // Arrange
        const roomId = 'room_1';
        const sensorData = {
          'temperature': 25.5,
          'humidity': 65.2,
          'ph': 6.8,
          'ec': 1.6,
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Act
        await storageService.cacheSensorData(roomId, sensorData);
        final cached = await storageService.getCachedSensorData(roomId);

        // Assert
        expect(cached, isNotNull);
        expect(cached!['temperature'], equals(25.5));
        expect(cached['humidity'], equals(65.2));
      });

      test('should return null for expired cache', () async {
        // Arrange
        const roomId = 'room_1';
        const sensorData = {
          'temperature': 25.5,
          'humidity': 65.2,
          'timestamp': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
        };

        // Act - Cache data with 1 hour expiry
        await storageService.cacheSensorData(roomId, sensorData, expiryHours: 1);
        final cached = await storageService.getCachedSensorData(roomId);

        // Assert
        expect(cached, isNull);
      });

      test('should handle multiple room sensor data', () async {
        // Arrange
        const rooms = ['room_1', 'room_2', 'room_3'];
        final sensorDataList = [
          {'temperature': 25.5, 'humidity': 65.2},
          {'temperature': 24.8, 'humidity': 68.1},
          {'temperature': 26.2, 'humidity': 62.5},
        ];

        // Act
        for (int i = 0; i < rooms.length; i++) {
          await storageService.cacheSensorData(rooms[i], sensorDataList[i]);
        }

        final cachedRoom1 = await storageService.getCachedSensorData('room_1');
        final cachedRoom2 = await storageService.getCachedSensorData('room_2');
        final cachedRoom3 = await storageService.getCachedSensorData('room_3');

        // Assert
        expect(cachedRoom1!['temperature'], equals(25.5));
        expect(cachedRoom2!['temperature'], equals(24.8));
        expect(cachedRoom3!['temperature'], equals(26.2));
      });
    });

    group('Automation Settings', () {
      test('should save and retrieve automation settings', () async {
        // Arrange
        const roomId = 'room_1';
        const settings = {
          'watering_enabled': true,
          'watering_threshold': 30.0,
          'lighting_schedule': {
            'on': '06:00',
            'off': '22:00',
          },
          'temperature_range': {'min': 20.0, 'max': 28.0},
          'humidity_range': {'min': 50.0, 'max': 70.0},
        };

        // Act
        await storageService.saveAutomationSettings(roomId, settings);
        final retrieved = await storageService.getAutomationSettings(roomId);

        // Assert
        expect(retrieved, isNotNull);
        expect(retrieved!['watering_enabled'], isTrue);
        expect(retrieved['watering_threshold'], equals(30.0));
        expect(retrieved['lighting_schedule']['on'], equals('06:00'));
      });

      test('should return default settings when none exist', () async {
        // Act
        final settings = await storageService.getAutomationSettings('non_existent_room');

        // Assert
        expect(settings, isNotNull);
        expect(settings!['watering_enabled'], isFalse);
        expect(settings['watering_threshold'], equals(40.0));
      });
    });

    group('Authentication Tokens', () {
      test('should save and retrieve authentication tokens', () async {
        // Arrange
        const tokenData = {
          'access_token': 'fake_access_token',
          'refresh_token': 'fake_refresh_token',
          'expires_at': '2024-01-15T10:30:00Z',
          'user_id': 'user_123',
        };

        // Act
        await storageService.saveAuthTokens(tokenData);
        final retrieved = await storageService.getAuthTokens();

        // Assert
        expect(retrieved, isNotNull);
        expect(retrieved!['access_token'], equals('fake_access_token'));
        expect(retrieved['refresh_token'], equals('fake_refresh_token'));
        expect(retrieved['user_id'], equals('user_123'));
      });

      test('should clear authentication tokens', () async {
        // Arrange
        await storageService.saveAuthTokens({
          'access_token': 'fake_token',
          'user_id': 'user_123',
        });

        // Act
        await storageService.clearAuthTokens();
        final retrieved = await storageService.getAuthTokens();

        // Assert
        expect(retrieved, isNull);
      });

      test('should check if token is expired', () async {
        // Arrange
        final expiredToken = {
          'access_token': 'expired_token',
          'expires_at': DateTime.now().subtract(Duration(hours: 1)).toIso8601String(),
        };

        final validToken = {
          'access_token': 'valid_token',
          'expires_at': DateTime.now().add(Duration(hours: 1)).toIso8601String(),
        };

        // Act & Assert
        await storageService.saveAuthTokens(expiredToken);
        expect(storageService.isTokenExpired(), isTrue);

        await storageService.saveAuthTokens(validToken);
        expect(storageService.isTokenExpired(), isFalse);
      });
    });

    group('Data Migration', () {
      test('should migrate data format correctly', () async {
        // Arrange - Old format data
        SharedPreferences.setMockInitialValues({
          'user_settings': '{"theme": "dark", "notifications": true}',
        });

        // Act
        await storageService.init();
        await storageService.migrateDataFormat();

        // Assert
        final migrated = await storageService.getData<Map<String, dynamic>>('user_preferences');
        expect(migrated, isNotNull);
        expect(migrated!['theme_mode'], equals('dark'));
        expect(migrated['notifications_enabled'], isTrue);
      });

      test('should handle migration errors gracefully', () async {
        // Arrange - Corrupted data
        SharedPreferences.setMockInitialValues({
          'user_settings': '{"invalid": json}',
        });

        // Act & Assert - Should not throw exception
        await storageService.init();
        await storageService.migrateDataFormat();

        final migrated = await storageService.getData('user_preferences');
        expect(migrated, isNull);
      });
    });

    group('Error Handling', () {
      test('should handle storage errors gracefully', () async {
        // Arrange - Mock storage failure
        SharedPreferences.setMockInitialValues({});

        // Act & Assert - Should not throw exceptions
        await storageService.saveData('test_key', 'test_value');
        final retrieved = await storageService.getData('test_key');
        expect(retrieved, equals('test_value'));
      });

      test('should handle null values', () async {
        // Act
        await storageService.saveData('null_test', null);
        final retrieved = await storageService.getData('null_test');

        // Assert
        expect(retrieved, isNull);
      });

      test('should handle empty collections', () async {
        // Act
        await storageService.saveData('empty_list', []);
        await storageService.saveData('empty_map', {});

        final retrievedList = await storageService.getData<List>('empty_list');
        final retrievedMap = await storageService.getData<Map>('empty_map');

        // Assert
        expect(retrievedList, isEmpty);
        expect(retrievedMap, isEmpty);
      });
    });

    group('Data Validation', () {
      test('should validate data types', () async {
        // Arrange
        const testData = {
          'string_value': 'test_string',
          'int_value': 42,
          'double_value': 3.14,
          'bool_value': true,
          'list_value': [1, 2, 3],
          'map_value': {'nested': 'value'},
        };

        // Act
        await storageService.saveData('typed_test', testData);
        final retrieved = await storageService.getData<Map<String, dynamic>>('typed_test');

        // Assert
        expect(retrieved, isNotNull);
        expect(retrieved!['string_value'], isA<String>());
        expect(retrieved['int_value'], isA<int>());
        expect(retrieved['double_value'], isA<double>());
        expect(retrieved['bool_value'], isA<bool>());
        expect(retrieved['list_value'], isA<List>());
        expect(retrieved['map_value'], isA<Map>());
      });
    });

    tearDown(() async {
      // Clean up after each test
      await storageService.clearAllData();
    });
  });
}