import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:provider/provider.dart';

import 'package:mouseplate/controllers/app_controller.dart';
import 'package:mouseplate/nav.dart';
import 'package:mouseplate/theme.dart';

/// Main entry point for the application
///
/// This sets up:
/// - go_router navigation
/// - Material 3 dark UI (`theme` and `darkTheme` both use [darkTheme] so they never mix)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch any uncaught (non-Flutter framework) errors.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error: $error');
    debugPrint(stack.toString());
    return true;
  };

  // Ensure framework errors (like the red-screen in your screenshot) are always
  // printed to the Debug Console with a stack trace.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) debugPrint(details.stack.toString());
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('ErrorWidget: ${details.exceptionAsString()}');
    if (details.stack != null) debugPrint(details.stack.toString());
    return ErrorWidget(details.exception);
  };

  final controller = AppController();
  await controller.load();

  runZonedGuarded(
    () => runApp(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MyApp(),
      ),
    ),
    (error, stack) {
      debugPrint('runZonedGuarded error: $error');
      debugPrint(stack.toString());
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // As you extend the app, use MultiProvider to wrap the app
    // and provide state to all widgets
    // Example:
    // return MultiProvider(
    //   providers: [
    //     ChangeNotifierProvider(create: (_) => ExampleProvider()),
    //   ],
    //   child: MaterialApp.router(
    //     title: 'Dreamflow Starter',
    //     debugShowCheckedModeBanner: false,
    //     routerConfig: AppRouter.router,
    //   ),
    // );
    // Single visual theme in both slots so Material never mixes light `theme` with dark widgets.
    final uiTheme = darkTheme;
    return MaterialApp.router(
      title: 'Enchanted Credits',
      debugShowCheckedModeBanner: false,

      theme: uiTheme,
      darkTheme: uiTheme,
      themeMode: ThemeMode.dark,

      // Router configuration
      routerConfig: AppRouter.router(Provider.of<AppController>(context, listen: false)),
    );
  }
}
