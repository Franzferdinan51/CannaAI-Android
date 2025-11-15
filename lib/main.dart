import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/local_data_service.dart';
import 'core/services/local_sensor_service.dart';
import 'core/services/local_automation_service.dart';
import 'core/services/local_ai_service.dart';
import 'core/services/api_service.dart';
import 'core/services/socket_service.dart';
import 'core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Logger logger = Logger();

  try {
    logger.i('🌱 Initializing CannaAI Pro (Offline Mode)...');

    // Initialize offline local services
    logger.i('📊 Initializing local data service...');
    await LocalDataService().initialize();

    logger.i('🤖 Initializing local AI service...');
    // AI service initializes on demand

    logger.i('🌡️ Initializing local sensor service...');
    await LocalSensorService().initialize();

    logger.i('⚙️ Initializing local automation service...');
    await LocalAutomationService().initialize();

    logger.i('🔔 Initializing local notification service...');
    await LocalNotificationService().initialize();

    // Initialize API service (now local-only)
    logger.i('🔌 Initializing local API service...');
    await ApiService().initialize();

    // Initialize socket service (now local event service)
    logger.i('📡 Initializing local event service...');
    await LocalEventService().connect();

    logger.i('🎉 All offline services initialized successfully!');

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    runApp(
      const ProviderScope(
        child: CannaAIApp(),
      ),
    );

  } catch (e, stackTrace) {
    logger.e('❌ Failed to initialize CannaAI Pro: $e');
    logger.e('Stack trace: $stackTrace');

    // Run app with error state
    runApp(
      ProviderScope(
        child: MaterialApp(
          title: 'CannaAI Pro - Error',
          home: ErrorScreen(error: e.toString()),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class CannaAIApp extends ConsumerWidget {
  const CannaAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRouter = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'CannaAI Pro - Offline Edition',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // Router configuration
      routerConfig: appRouter,

      // Builder for additional configuration
      builder: (context, child) {
        return MediaQuery(
          // Prevent text scaling beyond certain limits
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2),
          ),
          child: child!,
        );
      },
    );
  }
}

/// Error screen for initialization failures
class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CannaAI Pro - Error',
      home: Scaffold(
        backgroundColor: Colors.green[50],
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Initialization Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'CannaAI Pro failed to start in offline mode.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Error: $error',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}