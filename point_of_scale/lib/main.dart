import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/warmup_service.dart';
import 'services/websocket_service.dart';

void main() {
  // Ensure Flutter is initialized before any other operations
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Add error handling for uncaught exceptions
  FlutterError.onError = (FlutterErrorDetails details) {
    print('🚨 Flutter Error: ${details.exception}');
    print('🚨 Stack trace: ${details.stack}');
  };

  // Start backend warmup service to prevent Render cold starts
  WarmupService.startWarmup();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Dispose WebSocket singleton when app is completely closed
    try {
      WebSocketService.instance.dispose();
      print('🔌 WebSocket singleton disposed on app closure');
    } catch (e) {
      print('⚠️ Error disposing WebSocket singleton: $e');
    }
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        print('📱 App paused - WebSocket will auto-reconnect when resumed');
        break;
      case AppLifecycleState.resumed:
        print('📱 App resumed - ensuring WebSocket connection');
        try {
          WebSocketService.instance.connect();
        } catch (e) {
          print('⚠️ Error reconnecting WebSocket on app resume: $e');
        }
        break;
      case AppLifecycleState.detached:
        print('📱 App detached - preparing for cleanup');
        break;
      case AppLifecycleState.inactive:
        // Don't disconnect on inactive state as it's triggered during normal navigation
        break;
      case AppLifecycleState.hidden:
        // Handle hidden state if needed
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TEPOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B8E7F),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        useMaterial3: true,
        // Performance optimizations
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const SplashScreen(),
      // Error handling
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
      // Add error handling for navigation
      navigatorObservers: [RouteObserver<Route<dynamic>>()],
    );
  }
}
