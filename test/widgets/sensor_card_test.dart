import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:canna_ai/core/widgets/sensor_card.dart';
import 'package:canna_ai/core/models/sensor_data.dart';
import 'package:canna_ai/core/theme/app_theme.dart';

void main() {
  group('SensorCard Widget Tests', () {
    late SensorData mockSensorData;

    setUp(() {
      mockSensorData = SensorData(
        roomId: 'room_1',
        temperature: 25.5,
        humidity: 65.2,
        ph: 6.8,
        ec: 1.6,
        co2: 800,
        vpd: 1.2,
        timestamp: DateTime.now(),
      );
    });

    testWidgets('renders sensor card with all data', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SensorCard(
              sensorData: mockSensorData,
              title: 'Room 1',
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify that all sensor values are displayed
      expect(find.text('Room 1'), findsOneWidget);
      expect(find.text('25.5°C'), findsOneWidget);
      expect(find.text('65.2%'), findsOneWidget);
      expect(find.text('6.8 pH'), findsOneWidget);
      expect(find.text('1.6 mS/cm'), findsOneWidget);
      expect(find.text('800 ppm'), findsOneWidget);
      expect(find.text('1.2 kPa'), findsOneWidget);
    });

    testWidgets('handles null sensor data gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SensorCard(
              sensorData: null,
              title: 'Room 1',
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify loading state or placeholder is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading sensor data...'), findsOneWidget);
    });

    testWidgets('calls onTap when card is tapped', (WidgetTester tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SensorCard(
              sensorData: mockSensorData,
              title: 'Room 1',
              onTap: () => wasTapped = true,
            ),
          ),
        ),
      );

      // Tap the card
      await tester.tap(find.byType(Card));
      await tester.pump();

      // Verify onTap was called
      expect(wasTapped, isTrue);
    });

    testWidgets('displays warning indicators for out-of-range values', (WidgetTester tester) async {
      // Create sensor data with out-of-range values
      final warningSensorData = SensorData(
        roomId: 'room_1',
        temperature: 35.0, // High temperature
        humidity: 85.0, // High humidity
        ph: 8.5, // High pH
        ec: 1.6,
        co2: 800,
        vpd: 1.2,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SensorCard(
              sensorData: warningSensorData,
              title: 'Room 1',
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify warning indicators are shown
      expect(find.byIcon(Icons.warning), findsAtLeastNWidgets(2));
      expect(find.text('High'), findsAtLeastNWidgets(2));
    });

    testWidgets('displays last updated timestamp', (WidgetTester tester) async {
      final now = DateTime.now();
      final sensorDataWithTimestamp = SensorData(
        roomId: 'room_1',
        temperature: 25.5,
        humidity: 65.2,
        ph: 6.8,
        ec: 1.6,
        co2: 800,
        vpd: 1.2,
        timestamp: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SensorCard(
              sensorData: sensorDataWithTimestamp,
              title: 'Room 1',
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify timestamp is displayed (format: "Last updated: X minutes ago")
      expect(find.textContaining('Last updated:'), findsOneWidget);
    });

    testWidgets('applies correct styling based on sensor status', (WidgetTester tester) async {
      // Create sensor data with healthy status
      final healthySensorData = SensorData(
        roomId: 'room_1',
        temperature: 24.0,
        humidity: 60.0,
        ph: 6.5,
        ec: 1.4,
        co2: 1000,
        vpd: 1.0,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SensorCard(
              sensorData: healthySensorData,
              title: 'Room 1',
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify card has green accent for healthy status
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, equals(Colors.green.withOpacity(0.1)));
    });

    testWidgets('supports custom themes', (WidgetTester tester) async {
      final customTheme = ThemeData(
        primarySwatch: Colors.purple,
        cardTheme: CardTheme(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: customTheme,
          home: Scaffold(
            body: SensorCard(
              sensorData: mockSensorData,
              title: 'Room 1',
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify custom theme is applied
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, equals(8));
    });

    testWidgets('handles accessibility properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SensorCard(
              sensorData: mockSensorData,
              title: 'Room 1',
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify accessibility labels are present
      expect(
        find.bySemanticsLabel('Room 1 sensor data card'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Temperature: 25.5°C'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Humidity: 65.2%'),
        findsOneWidget,
      );
    });

    testWidgets('displays connection status indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SensorCard(
              sensorData: mockSensorData,
              title: 'Room 1',
              isConnected: true,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify connection status indicator
      expect(find.byIcon(Icons.wifi), findsOneWidget);
      expect(find.bySemanticsLabel('Connected'), findsOneWidget);
    });

    testWidgets('shows offline indicator when disconnected', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SensorCard(
              sensorData: mockSensorData,
              title: 'Room 1',
              isConnected: false,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify offline indicator
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.bySemanticsLabel('Disconnected'), findsOneWidget);
    });
  });
}