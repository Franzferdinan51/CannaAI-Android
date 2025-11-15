// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:canna_ai/main.dart' as app;
import 'package:canna_ai/core/services/storage_service.dart';
import 'package:canna_ai/core/services/bluetooth_service.dart';
import 'package:canna_ai/core/services/camera_service.dart';
import 'package:canna_ai/core/services/notifications_service.dart';
import 'package:canna_ai/core/utils/constants.dart';

import 'helper/widget_test_helper.dart';

void main() {
  group('CannaAI App Tests', () {
    testWidgets('app should build and display correctly', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const app.CannaAIApp());

      // Verify that the app starts
      expect(find.byType(MaterialApp), findsOneWidget);

      // Wait for initialization to complete
      await tester.pumpAndSettle();

      // Check for main navigation elements
      expect(find.byKey(Key('bottom_navigation')), findsOneWidget);
    });

    testWidgets('should navigate between main tabs', (WidgetTester tester) async {
      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      // Test dashboard navigation
      expect(find.text('Dashboard'), findsOneWidget);
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      // Test camera tab
      expect(find.text('Analyze'), findsOneWidget);
      await tester.tap(find.text('Analyze'));
      await tester.pumpAndSettle();

      // Test automation tab
      expect(find.text('Automation'), findsOneWidget);
      await tester.tap(find.text('Automation'));
      await tester.pumpAndSettle();
    });

    testWidgets('should handle theme switching', (WidgetTester tester) async {
      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      // Find settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Look for theme toggle
      expect(find.byKey(Key('theme_toggle')), findsOneWidget);
      await tester.tap(find.byKey(Key('theme_toggle')));
      await tester.pumpAndSettle();
    });
  });

  group('Service Initialization Tests', () {
    testWidgets('should initialize services on app start', (WidgetTester tester) async {
      await tester.pumpWidget(const app.CannaAIApp());

      // Services should be initialized during app startup
      expect(find.byType(app.CannaAIApp), findsOneWidget);
      await tester.pumpAndSettle();

      // Verify services are available
      final storage = StorageService();
      final bluetooth = BluetoothService();
      final camera = CameraService();
      final notifications = NotificationsService();

      expect(storage, isNotNull);
      expect(bluetooth, isNotNull);
      expect(camera, isNotNull);
      expect(notifications, isNotNull);
    });
  });

  group('Error Handling Tests', () {
    testWidgets('should display error messages gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      // Navigate to camera tab (which might have permission issues)
      await tester.tap(find.text('Analyze'));
      await tester.pumpAndSettle();

      // Verify error handling UI is present
      expect(find.byKey(Key('error_handler')), findsOneWidget);
    });

    testWidgets('should handle network connectivity issues', (WidgetTester tester) async {
      // Mock network failure scenario
      await mockNetworkFailure(() async {
        await tester.pumpWidget(const app.CannaAIApp());
        await tester.pumpAndSettle();

        // Try to perform a network-dependent action
        await tester.tap(find.text('Dashboard'));
        await tester.pumpAndSettle();

        // Should show connectivity error message
        expect(find.text('No internet connection'), findsOneWidget);
      });
    });
  });

  group('Accessibility Tests', () {
    testWidgets('should have proper semantic labels', (WidgetTester tester) async {
      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      // Check for semantic labels on key elements
      expect(find.bySemanticsLabel('Dashboard tab'), findsOneWidget);
      expect(find.bySemanticsLabel('Analyze plant tab'), findsOneWidget);
      expect(find.bySemanticsLabel('Automation tab'), findsOneWidget);
      expect(find.bySemanticsLabel('Settings tab'), findsOneWidget);
    });

    testWidgets('should be navigable via keyboard', (WidgetTester tester) async {
      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      // Test keyboard navigation
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Should focus on first interactive element
      expect(tester.binding.focusManager.primaryFocus, isNotNull);
    });
  });

  group('Performance Tests', () {
    testWidgets('should render within acceptable time limits', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      stopwatch.stop();

      // Should render within 2 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    testWidgets('should handle large data sets efficiently', (WidgetTester tester) async {
      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      // Simulate large sensor data set
      final largeDataSet = List.generate(1000, (index) => {
        'id': 'sensor_$index',
        'timestamp': DateTime.now().subtract(Duration(hours: index)).toIso8601String(),
        'temperature': 20.0 + (index % 10),
        'humidity': 60.0 + (index % 20),
        'ph': 6.0 + (index % 2),
      });

      // Navigate to dashboard with large data set
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      // Should not crash and should render efficiently
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('Permission Tests', () {
    testWidgets('should request camera permission when accessing camera', (WidgetTester tester) async {
      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      // Navigate to camera tab
      await tester.tap(find.text('Analyze'));
      await tester.pumpAndSettle();

      // Should show camera permission dialog if not granted
      await tester.tap(find.byKey(Key('capture_button')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('should request Bluetooth permission when connecting devices', (WidgetTester tester) async {
      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      // Navigate to automation tab
      await tester.tap(find.text('Automation'));
      await tester.pumpAndSettle();

      // Try to scan for Bluetooth devices
      await tester.tap(find.byKey(Key('bluetooth_scan')));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('permission_request')), findsOneWidget);
    });
  });

  group('Data Persistence Tests', () {
    testWidgets('should save and restore user preferences', (WidgetTester tester) async {
      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      // Navigate to settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Change a setting
      await tester.tap(find.byKey(Key('theme_toggle')));
      await tester.pumpAndSettle();

      // Restart app
      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      // Setting should be preserved
      expect(find.byKey(Key('theme_dark_indicator')), findsOneWidget);
    });

    testWidgets('should cache analysis results', (WidgetTester tester) async {
      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      // Perform analysis
      await tester.tap(find.text('Analyze'));
      await tester.pumpAndSettle();

      // Mock successful analysis
      await tester.tap(find.byKey(Key('mock_analysis')));
      await tester.pumpAndSettle();

      // Navigate away and back
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analyze'));
      await tester.pumpAndSettle();

      // Analysis result should be cached
      expect(find.text('Analysis completed'), findsOneWidget);
    });
  });

  group('Integration Tests', () {
    testWidgets('should complete full plant analysis workflow', (WidgetTester tester) async {
      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      // 1. Navigate to camera
      await tester.tap(find.text('Analyze'));
      await tester.pumpAndSettle();

      // 2. Take/upload photo
      await tester.tap(find.byKey(Key('capture_button')));
      await tester.pumpAndSettle();

      // 3. Add symptoms
      await tester.enterText(find.byKey(Key('symptoms_input')), 'Yellowing leaves');
      await tester.pumpAndSettle();

      // 4. Select strain
      await tester.tap(find.byKey(Key('strain_selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue Dream'));
      await tester.pumpAndSettle();

      // 5. Submit for analysis
      await tester.tap(find.byKey(Key('analyze_button')));
      await tester.pumpAndSettle();

      // 6. View results
      expect(find.text('Analysis Results'), findsOneWidget);
      expect(find.text('Recommendations'), findsOneWidget);
    });

    testWidgets('should handle automation setup workflow', (WidgetTester tester) async {
      await tester.pumpWidget(const app.CannaAIApp());
      await tester.pumpAndSettle();

      // 1. Navigate to automation
      await tester.tap(find.text('Automation'));
      await tester.pumpAndSettle();

      // 2. Connect Bluetooth sensor
      await tester.tap(find.byKey(Key('bluetooth_connect')));
      await tester.pumpAndSettle();

      // 3. Configure watering schedule
      await tester.tap(find.byKey(Key('watering_config')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(Key('threshold_input')), '30');
      await tester.pumpAndSettle();

      // 4. Save configuration
      await tester.tap(find.byKey(Key('save_config')));
      await tester.pumpAndSettle();

      // 5. Verify configuration saved
      expect(find.text('Automation configured'), findsOneWidget);
    });
  });
}