import 'package:flutter/material.dart';

import 'screens/hod_dashboard_screen.dart';
import 'screens/lecturer_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/principal_dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/student_dashboard_screen.dart';
import 'screens/unsupported_role_screen.dart';
import 'services/api.dart';
import 'services/google_auth.dart';
import 'services/session_store.dart';
import 'state/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = AmsApiService.fromEnvironment();
  final googleAuth = await GoogleSignInAuthClient.buildFromEnvironment(
    api: api,
  );

  final sessionController = SessionController(
    api: api,
    store: SharedPreferencesSessionStore(),
    googleAuth: googleAuth,
  );
  await sessionController.initialize();

  runApp(AmsApp(sessionController: sessionController));
}

class AmsApp extends StatefulWidget {
  const AmsApp({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<AmsApp> createState() => _AmsAppState();
}

class _AmsAppState extends State<AmsApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  SessionStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    _lastStatus = widget.sessionController.status;
    widget.sessionController.addListener(_handleSessionChange);
  }

  @override
  void dispose() {
    widget.sessionController.removeListener(_handleSessionChange);
    widget.sessionController.dispose();
    super.dispose();
  }

  void _handleSessionChange() {
    final currentStatus = widget.sessionController.status;
    if (_lastStatus != currentStatus) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      _lastStatus = currentStatus;
    }
  }

  ThemeData _buildTheme() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF0F766E),
          secondary: const Color(0xFFB45309),
          surface: const Color(0xFFFFFBF5),
          surfaceContainerHighest: const Color(0xFFF1E7D8),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF3EDE2),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: const Color(0xFF1E293B),
        displayColor: const Color(0xFF0F172A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.primary,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.92),
        shadowColor: const Color(0x1F0F172A),
        elevation: 1.5,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFCCD5DF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFD7DFE8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0F172A),
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildHome() {
    switch (widget.sessionController.status) {
      case SessionStatus.loading:
        return const SplashScreen();
      case SessionStatus.signedOut:
        return LoginScreen(sessionController: widget.sessionController);
      case SessionStatus.unsupportedRole:
        return UnsupportedRoleScreen(
          sessionController: widget.sessionController,
        );
      case SessionStatus.authenticated:
        final user = widget.sessionController.user;
        if (user == null) {
          return LoginScreen(sessionController: widget.sessionController);
        }

        return switch (user.role) {
          'principal' => PrincipalDashboardScreen(
            sessionController: widget.sessionController,
          ),
          'hod' => HodDashboardScreen(
            sessionController: widget.sessionController,
          ),
          'lecturer' => LecturerHomeScreen(
            sessionController: widget.sessionController,
          ),
          'student' => StudentDashboardScreen(
            sessionController: widget.sessionController,
          ),
          _ => UnsupportedRoleScreen(
            sessionController: widget.sessionController,
          ),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.sessionController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Attendance Master Scholar',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          theme: _buildTheme(),
          home: _buildHome(),
        );
      },
    );
  }
}
