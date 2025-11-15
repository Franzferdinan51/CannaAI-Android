import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

// Mock HTTP Client for testing
class MockHttpClient extends Mock implements http.Client {}

// Helper functions for widget testing
class WidgetTestHelper {
  static Future<void> mockNetworkFailure(Function() testFunction) async {
    // Mock network failure scenario
    HttpOverrides.global = _MockHttpOverrides();

    try {
      await testFunction();
    } finally {
      // Reset HTTP overrides
      HttpOverrides.global = null;
    }
  }

  static Future<void> mockSuccessResponse(String url, String response) async {
    HttpOverrides.global = _SuccessMockHttpOverrides(url, response);
  }

  static Widget createTestApp(Widget child) {
    return MaterialApp(
      home: child,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
    );
  }

  static Future<void> pumpAndSettleWithDelay(
    WidgetTester tester, {
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    await tester.pumpAndSettle();
    await Future.delayed(delay);
    await tester.pump();
  }

  static Finder findWidgetByKey(Key key) {
    return find.byKey(key);
  }

  static Finder findWidgetByText(String text) {
    return find.text(text);
  }

  static Future<void> enterTextAndSettle(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  static Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  static Future<void> longPressAndSettle(WidgetTester tester, Finder finder) async {
    await tester.longPress(finder);
    await tester.pumpAndSettle();
  }

  static Future<void> doubleTapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.doubleTap(finder);
    await tester.pumpAndSettle();
  }

  static Future<void> dragAndSettle(
    WidgetTester tester,
    Finder finder,
    Offset offset,
  ) async {
    await tester.drag(finder, offset);
    await tester.pumpAndSettle();
  }

  static Future<void> scrollAndSettle(
    WidgetTester tester,
    Finder finder, {
    double delta = 100.0,
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    await tester.fling(
      finder,
      const Offset(0, -100), // Scroll up
      1000, // Velocity
    );
    await tester.pumpAndSettle();
  }

  static bool widgetExists(Finder finder) {
    return finder.evaluate().isNotEmpty;
  }

  static bool widgetIsVisible(WidgetTester tester, Finder finder) {
    if (!widgetExists(finder)) return false;

    final widget = tester.widget(finder);
    final renderBox = tester.renderObject(finder) as RenderBox?;

    if (renderBox == null) return false;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return size.width > 0 &&
           size.height > 0 &&
           offset.dy >= 0;
  }

  static void expectWidgetExists(Finder finder) {
    expect(finder, findsOneWidget);
  }

  static void expectWidgetNotExists(Finder finder) {
    expect(finder, findsNothing);
  }

  static void expectWidgetVisible(WidgetTester tester, Finder finder) {
    expect(widgetIsVisible(tester, finder), isTrue);
  }

  static void expectWidgetNotVisible(WidgetTester tester, Finder finder) {
    expect(widgetIsVisible(tester, finder), isFalse);
  }

  static Size getWidgetSize(WidgetTester tester, Finder finder) {
    final renderBox = tester.renderObject(finder) as RenderBox;
    return renderBox.size;
  }

  static Offset getWidgetPosition(WidgetTester tester, Finder finder) {
    final renderBox = tester.renderObject(finder) as RenderBox;
    return renderBox.localToGlobal(Offset.zero);
  }

  static Future<void> waitForAnimation(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final future = tester.pumpAndSettle();
    await future.timeout(timeout);
  }

  static void printWidgetTree(WidgetTester tester) {
    debugDumpApp();
  }

  static Future<void> screenshot(
    WidgetTester tester,
    String name, {
    bool fullScreen = false,
  }) async {
    await binding.takeScreenshot(name);
  }

  // Permission helpers
  static Future<void> grantCameraPermission(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/base64',
      StringCodec().encodeMessage(
        'camera:checkPermission',
      ),
      (data) {},
    );

    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/base64',
      StringCodec().encodeMessage(
        'camera:requestPermission',
      ),
      (data) {},
    );
  }

  static Future<void> grantBluetoothPermission(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/base64',
      StringCodec().encodeMessage(
        'bluetooth:checkPermission',
      ),
      (data) {},
    );

    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/base64',
      StringCodec().encodeMessage(
        'bluetooth:requestPermission',
      ),
      (data) {},
    );
  }

  static Future<void> grantStoragePermission(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/base64',
      StringCodec().encodeMessage(
        'storage:checkPermission',
      ),
      (data) {},
    );

    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/base64',
      StringCodec().encodeMessage(
        'storage:requestPermission',
      ),
      (data) {},
    );
  }
}

// Custom HTTP Overrides for testing
class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _SuccessMockHttpOverrides extends HttpOverrides {
  final String _url;
  final String _response;

  _SuccessMockHttpOverrides(this._url, this._response);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _SuccessHttpClient(_url, _response);
  }
}

class _MockHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Future.value(
      http.StreamedResponse(
        Stream.value('Network Error'.codeUnits),
        500,
        reasonPhrase: 'Network Error',
      ),
    );
  }
}

class _SuccessHttpClient extends http.BaseClient {
  final String _url;
  final String _response;

  _SuccessHttpClient(this._url, this._response);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.toString() == _url) {
      return Future.value(
        http.StreamedResponse(
          Stream.value(_response.codeUnits),
          200,
          reasonPhrase: 'OK',
        ),
      );
    }

    return Future.value(
      http.StreamedResponse(
        Stream.value('Not Found'.codeUnits),
        404,
        reasonPhrase: 'Not Found',
      ),
    );
  }
}

// Custom matcher for better test assertions
class IsVisible extends Matcher {
  const IsVisible();

  @override
  Description describe(Description description) {
    return description.add('is visible on screen');
  }

  @override
  bool matches(covariant Finder item, Map matchState) {
    final tester = TestWidgetsFlutterBinding.instance;
    final renderBox = tester.renderObject(item) as RenderBox?;

    if (renderBox == null) return false;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return size.width > 0 &&
           size.height > 0 &&
           offset.dy >= 0 &&
           offset.dy <= tester.window.physicalSize.height;
  }
}

// Custom finders for better test readability
class CustomFinders {
  static Finder byTestId(String testId) {
    return find.byKey(ValueKey(testId));
  }

  static Finder byLabelText(String label) {
    return find.bySemanticsLabel(label);
  }

  static Finder byIconData(IconData icon) {
    return find.byIcon(icon);
  }

  static Finder byWidgetType<T extends Widget>() {
    return find.byType(T);
  }

  static Finder byWidgetTypeAndKey<T extends Widget>(Key key) {
    return find.byWidgetPredicate((widget) => widget is T && widget.key == key);
  }

  static Finder byTextContaining(String text) {
    return find.byWidgetPredicate((widget) {
      if (widget is Text) {
        final data = widget.data;
        return data is String && data.contains(text);
      }
      return false;
    });
  }

  static Finder byTooltip(String message) {
    return find.byTooltip(message);
  }
}