import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:canna_ai/main.dart' as app;
import 'package:canna_ai/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:canna_ai/features/automation/presentation/pages/automation_page.dart';
import 'package:canna_ai/features/analytics/presentation/pages/analytics_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CannaAI App Flow Tests', () {
    testWidgets('complete user journey - dashboard to automation', (WidgetTester tester) async {
      // Initialize the app
      app.main();
      await tester.pumpAndSettle();

      // Verify dashboard is loaded
      expect(find.byType(DashboardPage), findsOneWidget);

      // Check for key dashboard elements
      expect(find.text('Overview'), findsOneWidget);
      expect(find.textContaining('Rooms'), findsAtLeastNWidgets(1));

      // Navigate to automation tab
      await tester.tap(find.text('Automation'));
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Verify automation page is loaded
      expect(find.byType(AutomationPage), findsOneWidget);
      expect(find.text('Automation Controls'), findsOneWidget);

      // Test automation controls
      expect(find.text('Watering'), findsOneWidget);
      expect(find.text('Lighting'), findsOneWidget);
      expect(find.text('Climate'), findsOneWidget);

      // Toggle watering control
      await tester.tap(find.bySemanticsLabel('Toggle watering'));
      await tester.pumpAndSettle();

      // Verify watering settings dialog appears
      expect(find.text('Watering Settings'), findsOneWidget);
      expect(find.byType(Slider), findsAtLeastNWidgets(1));

      // Adjust watering threshold
      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pumpAndSettle();

      // Save settings
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Navigate to analytics
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Verify analytics page is loaded
      expect(find.byType(AnalyticsPage), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);

      // Check for analytics components
      expect(find.text('Temperature Trends'), findsOneWidget);
      expect(find.text('Humidity Levels'), findsOneWidget);
      expect(find.byType(Card), findsAtLeastNWidgets(3));
    });

    testWidgets('sensor monitoring flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Wait for sensor data to load
      await tester.pumpAndSettle(Duration(seconds: 5));

      // Verify sensor cards are present
      expect(find.textContaining('Room'), findsAtLeastNWidgets(1));

      // Tap on first room to view details
      await tester.tap(find.textContaining('Room').first);
      await tester.pumpAndSettle();

      // Verify room details page
      expect(find.textContaining('Room Details'), findsOneWidget);
      expect(find.textContaining('Temperature'), findsOneWidget);
      expect(find.textContaining('Humidity'), findsOneWidget);

      // Test real-time updates by waiting
      await tester.pumpAndSettle(Duration(seconds: 10));

      // Verify data has been updated (timestamp should change)
      expect(find.textContaining('Last updated:'), findsOneWidget);
    });

    testWidgets('plant analysis flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to plant analysis section
      await tester.tap(find.text('Analyze'));
      await tester.pumpAndSettle();

      // Verify analysis page is loaded
      expect(find.text('Plant Analysis'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Select from Gallery'), findsOneWidget);

      // Test photo selection flow
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      // Note: In a real test, you'd need to mock camera functionality
      // For integration testing, verify the UI responds correctly
      expect(find.textContaining('Camera'), findsAtLeastNWidgets(1));

      // Go back to main dashboard
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('settings and preferences flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Verify settings page
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Data & Privacy'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);

      // Test notification settings
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      // Verify notification preferences
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Alert Thresholds'), findsOneWidget);

      // Toggle push notifications
      await tester.tap(find.bySemanticsLabel('Enable push notifications'));
      await tester.pumpAndSettle();

      // Go back
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('offline mode functionality', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Simulate offline mode by disabling network
      // Note: This would require additional setup in a real test environment

      // Verify offline indicator appears
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Test that cached data is still available
      expect(find.textContaining('Room'), findsAtLeastNWidgets(1));

      // Test that new data requests show appropriate messaging
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();

      // Verify offline messaging
      expect(find.textContaining('Offline'), findsOneWidget);
      expect(find.text('Using cached data'), findsOneWidget);
    });

    testWidgets('performance and memory test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Measure initial performance
      final stopwatch = Stopwatch()..start();

      // Navigate through multiple screens rapidly
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.text('Automation'));
        await tester.pumpAndSettle(Duration(milliseconds: 500));

        await tester.tap(find.text('Analytics'));
        await tester.pumpAndSettle(Duration(milliseconds: 500));

        await tester.tap(find.text('Overview'));
        await tester.pumpAndSettle(Duration(milliseconds: 500));
      }

      stopwatch.stop();

      // Verify performance is acceptable (navigation should be under 2 seconds total)
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));

      // Check for memory leaks by ensuring no error dialogs appear
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('accessibility testing', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Test screen reader compatibility
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/accessibility',
        StringCodec().encodeMessage('{"type":"announce","message":"CannaAI dashboard loaded"}'),
        (data) {},
      );

      // Verify all major elements have semantic labels
      expect(find.bySemanticsLabel('Navigation menu'), findsOneWidget);
      expect(find.bySemanticsLabel('Dashboard'), findsOneWidget);
      expect(find.bySemanticsLabel('Automation'), findsOneWidget);
      expect(find.bySemanticsLabel('Analytics'), findsOneWidget);

      // Test keyboard navigation
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
    });

    testWidgets('error handling and recovery', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Test network error recovery
      // Simulate network error scenario
      await tester.pumpAndSettle(Duration(seconds: 5));

      // Verify error handling UI
      if (find.textContaining('Error').evaluate().isNotEmpty) {
        // Test retry functionality
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle(Duration(seconds: 3));
      }

      // Test graceful degradation
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}

// Helper extension for keyboard events
extension KeyboardTestHelpers on WidgetTester {
  Future<void> sendKeyEvent(LogicalKeyboardKey key) async {
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/keyevent',
      StringCodec().encodeMessage(
        '{"type":"keydown","keymap":"android","keyCode":${key.keyId}}',
      ),
      (data) {},
    );
  }
}