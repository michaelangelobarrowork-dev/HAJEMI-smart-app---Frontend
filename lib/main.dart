import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    // Note: You must configure Firebase via FlutterFire CLI or manually add google-services.json/GoogleService-Info.plist
    await Firebase.initializeApp();

    // Set background messaging handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    print('Firebase initialization failed: $e');
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final container = ProviderScope(child: const HajemiApp());

  runApp(container);
}

class HajemiApp extends ConsumerStatefulWidget {
  const HajemiApp({super.key});

  @override
  ConsumerState<HajemiApp> createState() => _HajemiAppState();
}

class _HajemiAppState extends ConsumerState<HajemiApp> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.init();
    notificationService.listenToTokenRefresh();

    // Register token if user is already logged in
    final loggedIn = await ref.read(authServiceProvider).isLoggedIn();
    if (loggedIn) {
      await notificationService.registerToken();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'HAJEMI Smart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
