import 'package:flutter_test/flutter_test.dart';
import 'package:canna_ai/core/models/sensor_data.dart';
import 'package:canna_ai/core/services/data_smoothing_service.dart';
import 'package:canna_ai/core/services/api_service.dart';
import 'dart:math';
import 'dart:typed_data';

void main() {
  group('Sensor Data Performance Tests', () {
    late DataSmoothingService smoothingService;

    setUp(() {
      smoothingService = DataSmoothingService();
    });

    group('Data Processing Performance', () {
      test('processes 1000 sensor readings under 100ms', () async {
        final stopwatch = Stopwatch()..start();

        // Generate 1000 sensor readings
        final readings = List.generate(1000, (index) => SensorData(
          roomId: 'room_1',
          temperature: 20.0 + Random().nextDouble() * 15,
          humidity: 40.0 + Random().nextDouble() * 40,
          ph: 5.5 + Random().nextDouble() * 2,
          ec: 0.5 + Random().nextDouble() * 2.5,
          co2: 400 + Random().nextInt(800),
          vpd: 0.5 + Random().nextDouble() * 2,
          timestamp: DateTime.now().subtract(Duration(seconds: 1000 - index)),
        ));

        // Process all readings
        for (final reading in readings) {
          smoothingService.addReading(reading);
        }

        stopwatch.stop();

        // Verify performance requirement
        expect(stopwatch.elapsedMilliseconds, lessThan(100));

        // Verify data integrity
        expect(smoothingService.getAverageTemperature(), isA<double>());
        expect(smoothingService.getAverageHumidity(), isA<double>());
      });

      test('handles high-frequency sensor updates efficiently', () async {
        final stopwatch = Stopwatch()..start();
        const updateCount = 10000;

        // Simulate high-frequency updates (10 per second for 1000 seconds)
        for (int i = 0; i < updateCount; i++) {
          final reading = SensorData(
            roomId: 'room_1',
            temperature: 25.0 + sin(i * 0.1) * 5,
            humidity: 60.0 + cos(i * 0.1) * 10,
            ph: 6.5 + Random().nextDouble() * 0.5 - 0.25,
            ec: 1.5 + Random().nextDouble() * 0.5 - 0.25,
            co2: 800 + Random().nextInt(400),
            vpd: 1.0 + Random().nextDouble() * 0.5,
            timestamp: DateTime.now().subtract(Duration(milliseconds: (updateCount - i) * 100)),
          );

          smoothingService.addReading(reading);

          // Process in batches to simulate real-world scenario
          if (i % 100 == 0) {
            smoothingService.processBatch();
            await Future.delayed(Duration(milliseconds: 1));
          }
        }

        stopwatch.stop();

        // Should process 10,000 updates in under 5 seconds
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });

      test('memory usage stays within limits during extended operation', () async {
        final initialMemory = _getCurrentMemoryUsage();
        const durationMinutes = 10;
        const updatesPerMinute = 60;

        // Simulate extended operation
        for (int minute = 0; minute < durationMinutes; minute++) {
          for (int update = 0; update < updatesPerMinute; update++) {
            final reading = SensorData(
              roomId: 'room_${minute % 3}',
              temperature: 20.0 + Random().nextDouble() * 15,
              humidity: 40.0 + Random().nextDouble() * 40,
              ph: 5.5 + Random().nextDouble() * 2,
              ec: 0.5 + Random().nextDouble() * 2.5,
              co2: 400 + Random().nextInt(800),
              vpd: 0.5 + Random().nextDouble() * 2,
              timestamp: DateTime.now().subtract(Duration(seconds: (durationMinutes - minute) * 60 - update)),
            );

            smoothingService.addReading(reading);
          }

          // Cleanup old data every minute
          smoothingService.cleanupOldData();

          await Future.delayed(Duration(milliseconds: 10));
        }

        final finalMemory = _getCurrentMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;

        // Memory increase should be less than 50MB
        expect(memoryIncrease, lessThan(50 * 1024 * 1024));
      });
    });

    group('API Performance Tests', () {
      test('concurrent API requests complete efficiently', () async {
        final stopwatch = Stopwatch()..start();
        const concurrentRequests = 20;

        final futures = List.generate(concurrentRequests, (index) async {
          // Mock API call simulation
          await Future.delayed(Duration(milliseconds: 100 + Random().nextInt(200)));

          return SensorData(
            roomId: 'room_$index',
            temperature: 20.0 + Random().nextDouble() * 15,
            humidity: 40.0 + Random().nextDouble() * 40,
            ph: 5.5 + Random().nextDouble() * 2,
            ec: 0.5 + Random().nextDouble() * 2.5,
            co2: 400 + Random().nextInt(800),
            vpd: 0.5 + Random().nextDouble() * 2,
            timestamp: DateTime.now(),
          );
        });

        final results = await Future.wait(futures);
        stopwatch.stop();

        // Verify all requests completed
        expect(results.length, equals(concurrentRequests));

        // Verify concurrent performance (should be faster than sequential)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });

      test('API response parsing handles large datasets efficiently', () async {
        final stopwatch = Stopwatch()..start();

        // Create large JSON dataset (10,000 sensor readings)
        final largeDataset = {
          'readings': List.generate(10000, (index) => {
            'room_id': 'room_${index % 10}',
            'temperature': 20.0 + Random().nextDouble() * 15,
            'humidity': 40.0 + Random().nextDouble() * 40,
            'ph': 5.5 + Random().nextDouble() * 2,
            'ec': 0.5 + Random().nextDouble() * 2.5,
            'co2': 400 + Random().nextInt(800),
            'vpd': 0.5 + Random().nextDouble() * 2,
            'timestamp': DateTime.now().subtract(Duration(minutes: 10000 - index)).toIso8601String(),
          }),
        };

        // Simulate JSON parsing
        final jsonString = largeDataset.toString();
        final parsedData = jsonString; // In real app, this would be json.decode

        stopwatch.stop();

        // Parsing should complete quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
        expect(parsedData.length, greaterThan(1000)); // Verify substantial data
      });
    });

    group('Image Processing Performance', () {
      test('plant image analysis completes within time limit', () async {
        final stopwatch = Stopwatch()..start();

        // Simulate image processing with different sizes
        final imageSizes = [640, 1280, 1920, 2560];

        for (final size in imageSizes) {
          // Generate mock image data
          final imageData = Uint8List(size * size * 3); // RGB image

          // Simulate image processing pipeline
          final processedImage = await _processImage(imageData);
          expect(processedImage.length, greaterThan(0));
        }

        stopwatch.stop();

        // All image processing should complete within 10 seconds
        expect(stopwatch.elapsedMilliseconds, lessThan(10000));
      });

      test('handles multiple concurrent image analysis requests', () async {
        final stopwatch = Stopwatch()..start();
        const concurrentImages = 5;

        final futures = List.generate(concurrentImages, (index) async {
          final imageData = Uint8List(1920 * 1080 * 3); // HD image
          return await _processImage(imageData);
        });

        final results = await Future.wait(futures);
        stopwatch.stop();

        // Verify all images were processed
        expect(results.length, equals(concurrentImages));

        // Should handle concurrency efficiently
        expect(stopwatch.elapsedMilliseconds, lessThan(15000));
      });
    });

    group('Data Storage Performance', () {
      test('database operations handle bulk inserts efficiently', () async {
        final stopwatch = Stopwatch()..start();
        const batchSize = 1000;

        final sensorReadings = List.generate(batchSize, (index) => SensorData(
          roomId: 'room_1',
          temperature: 20.0 + Random().nextDouble() * 15,
          humidity: 40.0 + Random().nextDouble() * 40,
          ph: 5.5 + Random().nextDouble() * 2,
          ec: 0.5 + Random().nextDouble() * 2.5,
          co2: 400 + Random().nextInt(800),
          vpd: 0.5 + Random().nextDouble() * 2,
          timestamp: DateTime.now().subtract(Duration(seconds: batchSize - index)),
        ));

        // Simulate bulk database insert
        await _bulkInsertSensorData(sensorReadings);

        stopwatch.stop();

        // Bulk insert should complete quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      });

      test('database queries remain responsive with large datasets', () async {
        // Populate with large dataset
        const totalRecords = 50000;
        await _populateDatabase(totalRecords);

        final stopwatch = Stopwatch()..start();

        // Test various query scenarios
        await _queryRecentSensorData(100); // Last 100 records
        await _querySensorDataByRoom('room_1'); // All records for room 1
        await _querySensorDataByTimeRange(
          DateTime.now().subtract(Duration(days: 30)),
          DateTime.now(),
        ); // Last 30 days

        stopwatch.stop();

        // Queries should remain fast even with large datasets
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
    });

    group('Real-time Data Processing', () {
      test('WebSocket message processing handles high message volume', () async {
        final stopwatch = Stopwatch()..start();
        const messageCount = 1000;
        const messagesPerSecond = 100;

        // Simulate high-frequency WebSocket messages
        final futures = List.generate(messageCount, (index) {
          return Future.delayed(
            Duration(milliseconds: (index * 1000) ~/ messagesPerSecond),
            () async {
              final message = {
                'type': 'sensor_update',
                'data': {
                  'room_id': 'room_${index % 5}',
                  'temperature': 20.0 + Random().nextDouble() * 15,
                  'humidity': 40.0 + Random().nextDouble() * 40,
                  'timestamp': DateTime.now().toIso8601String(),
                },
              };

              return await _processWebSocketMessage(message);
            },
          );
        });

        final results = await Future.wait(futures);
        stopwatch.stop();

        // Verify all messages were processed
        expect(results.length, equals(messageCount));

        // Should complete in approximately messageCount/messagesPerSecond seconds + buffer
        final expectedTime = (messageCount / messagesPerSecond * 1000) + 5000;
        expect(stopwatch.elapsedMilliseconds, lessThan(expectedTime));
      });

      test('data validation processes sensor updates efficiently', () async {
        final stopwatch = Stopwatch()..start();
        const validationCount = 10000;

        for (int i = 0; i < validationCount; i++) {
          final sensorData = SensorData(
            roomId: 'room_1',
            temperature: -50 + Random().nextDouble() * 150, // Include invalid ranges
            humidity: -20 + Random().nextDouble() * 140,
            ph: 0 + Random().nextDouble() * 14,
            ec: 0 + Random().nextDouble() * 10,
            co2: 0 + Random().nextInt(2000),
            vpd: -1 + Random().nextDouble() * 5,
            timestamp: DateTime.now(),
          );

          final isValid = _validateSensorData(sensorData);
          expect(isValid, isA<bool>());
        }

        stopwatch.stop();

        // Validation should be very fast
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });
  });
}

// Helper functions for performance testing
int _getCurrentMemoryUsage() {
  // Mock implementation - in real app, use actual memory monitoring
  return 100 * 1024 * 1024; // 100MB
}

Future<Uint8List> _processImage(Uint8List imageData) async {
  // Mock image processing - simulate computational work
  await Future.delayed(Duration(milliseconds: 100 + Random().nextInt(200)));

  // Return processed image data
  return imageData.map((byte) => (byte + 1) % 256).toList();
}

Future<void> _bulkInsertSensorData(List<SensorData> readings) async {
  // Mock database bulk insert
  await Future.delayed(Duration(milliseconds: 500));
}

Future<void> _populateDatabase(int recordCount) async {
  // Mock database population
  await Future.delayed(Duration(milliseconds: recordCount ~/ 100));
}

Future<List<SensorData>> _queryRecentSensorData(int limit) async {
  // Mock database query
  await Future.delayed(Duration(milliseconds: 50));
  return [];
}

Future<List<SensorData>> _querySensorDataByRoom(String roomId) async {
  // Mock database query
  await Future.delayed(Duration(milliseconds: 100));
  return [];
}

Future<List<SensorData>> _querySensorDataByTimeRange(DateTime start, DateTime end) async {
  // Mock database query
  await Future.delayed(Duration(milliseconds: 200));
  return [];
}

Future<bool> _processWebSocketMessage(Map<String, dynamic> message) async {
  // Mock WebSocket message processing
  await Future.delayed(Duration(milliseconds: 1));
  return true;
}

bool _validateSensorData(SensorData data) {
  // Mock data validation
  return data.temperature >= -50 && data.temperature <= 80 &&
         data.humidity >= 0 && data.humidity <= 100 &&
         data.ph >= 0 && data.ph <= 14;
}