import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/farm_store.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClimateCropApp());
}

class ClimateCropApp extends StatelessWidget {
  const ClimateCropApp({super.key});

  @override
  Widget build(BuildContext context) {
    // If the server says the session is no longer valid, go back to login.
    ApiClient.instance.onUnauthorized = () async {
      if (!Session.instance.isSignedIn) return;
      await Session.instance.signOut();
      FarmStore.instance.clear();
      final nav = navigatorKey.currentState;
      nav?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen(sessionExpired: true)),
        (_) => false,
      );
    };

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Climate and Crop Productivity',
      theme: buildTheme(),
      home: const StartupScreen(),
    );
  }
}

/// Splash that restores a saved login, then routes to the right screen.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final signedIn = await Session.instance.restore();
    if (!mounted) return;
    final resetToken = Uri.base.queryParameters['token'] ?? _fragmentToken(Uri.base.fragment);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => resetToken != null && resetToken.isNotEmpty
          ? ResetPasswordScreen(initialToken: resetToken)
          : (signedIn ? const DashboardScreen() : const LoginScreen()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

String? _fragmentToken(String fragment) {
  if (fragment.isEmpty) return null;
  try { return Uri.splitQueryString(fragment.startsWith('#') ? fragment.substring(1) : fragment)['token']; }
  catch (_) { return null; }
}

