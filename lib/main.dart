import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ==========================================
/// APP ENTRY POINT (main.dart)
/// ==========================================
///
/// This is the bootstrap of the networking application. 
/// It orchestrates the initialization of Firebase, local storage, 
/// environment variables, and GetX dependency injection.
///
/// INITIALIZATION SEQUENCE:
/// ------------------------------------------
/// 1. Engine Prep: `WidgetsFlutterBinding.ensureInitialized()`
/// 2. Local Storage: `GetStorage.init()` for fast theme/auth caching.
/// 3. Environment: Loads `.env` for Cloudinary/API keys.
/// 4. Firebase: Connects to Cloud Firestore/Auth using platform-specific options.
/// 5. Dependency Injection: 
///    - `Get.put()`: Essential services (Auth, Theme).
///    - `Get.lazyPut()`: Heavy controllers (Profile, Posts) loaded only on demand
///      to keep startup time fast.
/// 6. Data Seeding: Auto-generates demo content if the database is empty.
///
// --- CORE & CONTROLLERS ---
import 'core/app_theme.dart';
import 'controllers/theme_controller.dart';
import 'controllers/feed_controller.dart';
import 'controllers/post_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/connection_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/job_controller.dart';
import 'services/auth_service.dart';
import 'services/ad_service.dart';
import 'core/web_ad_registry.dart';
import 'services/database_seeder.dart';

// --- SCREENS ---
import 'screens/auth/splash_screen.dart';

void main() async {
  // 1. Prepare Flutter Engine
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Local Storage (fast)
  await GetStorage.init();

  // 2.1 Load Environment Variables (fail gracefully if missing)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ .env not found, using default environment variables");
  }

  // 3. Initialize Firebase (wait for it on web - critical dependency)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("✅ Firebase initialized");

  // 4. Initialize ESSENTIAL controllers only (lightweight)
  Get.put(AuthService());
  Get.put(AuthController());
  Get.put(ThemeController());
  Get.put(AdService()).init();
  
  // Register Web Ads (safe to call on mobile too as it has internal check, but keeping clean)
  if (kIsWeb) {
    registerAdSenseFactory();
  }

  // 5. Lazy-load HEAVY controllers (loaded only when first accessed)
  Get.lazyPut(() => FeedController(), fenix: true);
  Get.lazyPut(() => PostController(), fenix: true);
  Get.lazyPut(() => ProfileController(), fenix: true);
  Get.lazyPut(() => ConnectionController(), fenix: true);
  Get.lazyPut(() => ChatController(), fenix: true);
  Get.lazyPut(() => JobController(), fenix: true);

  // 6. SEED DATABASE in background (non-blocking - happens after app starts)
  DatabaseSeeder.seedDemoData()
      .then((_) {
        debugPrint("✅ Database seeded");
      })
      .catchError((e) {
        debugPrint("⚠️ Seeding skipped: $e");
      });

  runApp(const NetworkingApp());
}

class NetworkingApp extends StatelessWidget {
  const NetworkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Access theme controller to listen for dark/light mode toggles
    final themeController = Get.find<ThemeController>();

    return Obx(
      () => GetMaterialApp(
        title: 'The Quadrant',
        debugShowCheckedModeBanner: false,

        // --- THEME CONFIGURATION ---
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.theme,

        // --- ENTRY POINT ---
        home: const SplashScreen(),

        // Optional: Global transition for a professional feel
        defaultTransition: Transition.cupertino,
        transitionDuration: const Duration(milliseconds: 500),
        defaultGlobalState: true,
      ),
    );
  }
}
