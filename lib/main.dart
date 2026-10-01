import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'bootstrap/bootstrap_failure_screen.dart';
import 'bootstrap/firebase_bootstrap.dart';
import 'bootstrap/splash_screen.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/data/repositories/firebase_auth_repository.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/orders/presentation/providers/order_provider.dart';
import 'features/search/data/repositories/firestore_medicine_store.dart';
import 'features/search/presentation/providers/medicine_provider.dart';
import 'routing/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // runApp first, and let the splash cover the Firebase call. Awaiting the
  // bootstrap before this point would leave the Android launch background as
  // the only thing on screen, so the window would sit on the splash image for
  // the whole wait instead of a themed Flutter splash.
  runApp(const PharmaGuideApp());
}

class PharmaGuideApp extends StatefulWidget {
  const PharmaGuideApp({super.key, this.bootstrap});

  /// Overrides the real Firebase bootstrap. Tests inject a future here to
  /// control when the splash gives way, without touching Firebase.
  final Future<FirebaseBootstrapResult>? bootstrap;

  @override
  State<PharmaGuideApp> createState() => _PharmaGuideAppState();
}

class _PharmaGuideAppState extends State<PharmaGuideApp> {
  /// Firebase initialising typically takes well under 100ms, which would show
  /// the splash for a single frame and read as a flash rather than a splash.
  /// Holding it briefly is deliberately a little slower in exchange for not
  /// strobing. Set to Duration.zero to show the app as soon as it is ready.
  static const Duration _minimumSplash = Duration(milliseconds: 700);
  static const Duration _fade = Duration(milliseconds: 300);

  late final DateTime _startedAt = DateTime.now();
  late final Future<FirebaseBootstrapResult> _bootstrap;
  FirebaseBootstrapResult? _result;

  @override
  void initState() {
    super.initState();
    _bootstrap = widget.bootstrap ?? FirebaseBootstrap.initialize();
    _revealWhenReady();
  }

  Future<void> _revealWhenReady() async {
    final result = await _bootstrap;

    final remaining = _minimumSplash - DateTime.now().difference(_startedAt);
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }

    // The widget can be disposed while the bootstrap is in flight.
    if (!mounted) return;
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return AnimatedSwitcher(
      duration: _fade,
      child: result == null
          ? const SplashScreen(key: ValueKey('splash'))
          : _buildResolved(result),
    );
  }

  Widget _buildResolved(FirebaseBootstrapResult result) {
    if (!result.isSuccess) {
      return MaterialApp(
        key: const ValueKey('bootstrap-failure'),
        title: 'PharmaGuide',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: ThemeMode.light,
        home: BootstrapFailureScreen(result: result),
      );
    }

    return MultiProvider(
      key: const ValueKey('app'),
      providers: [
        Provider<AuthRepository>(create: (_) => FirebaseAuthRepository()),
        // One Firestore handle for the whole app. FirebaseFirestore.instance is
        // already a singleton, so this is a shared handle rather than a shared
        // database, and every store can be built from the same object.
        Provider<FirebaseFirestore>(
          create: (_) => FirebaseFirestore.instance,
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<AuthRepository>()),
        ),
        // Above the router, so the price list outlives a tab switch. Built from a
        // factory because the store is scoped to a user id, and signing in as
        // somebody else has to give it a different one.
        ChangeNotifierProvider<MedicineProvider>(
          create: (ctx) {
            final firestore = ctx.read<FirebaseFirestore>();
            return MedicineProvider(
              auth: ctx.read<AuthProvider>(),
              storeFor: (uid) =>
                  FirestoreMedicineStore(firestore: firestore, uid: uid),
            );
          },
        ),
        // Above the router, so the order outlives a tab switch. Constructed
        // against auth so signing out empties it.
        ChangeNotifierProvider<OrderProvider>(
          create: (ctx) => OrderProvider(auth: ctx.read<AuthProvider>()),
        ),
        Provider<GoRouter>(
          create: (ctx) =>
              createAppRouter(refreshListenable: ctx.read<AuthProvider>()),
          dispose: (_, router) => router.dispose(),
        ),
      ],
      child: const App(),
    );
  }
}
