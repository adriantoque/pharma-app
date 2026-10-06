import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'bootstrap/bootstrap_failure_screen.dart';
import 'bootstrap/firebase_bootstrap.dart';
import 'bootstrap/splash_screen.dart';
import 'core/connectivity/connection_source.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/data/repositories/firebase_auth_repository.dart';
import 'features/auth/data/repositories/offline_session.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/orders/data/repositories/local_order_draft_store.dart';
import 'features/orders/data/repositories/local_order_history_repository.dart';
import 'features/orders/data/repositories/order_draft_store.dart';
import 'features/orders/data/repositories/order_history_repository.dart';
import 'features/orders/data/repositories/firestore_order_history_repository.dart';
import 'features/orders/presentation/providers/order_provider.dart';
import 'features/orders/presentation/providers/orders_provider.dart';
import 'features/search/data/repositories/firestore_medicine_store.dart';
import 'features/search/data/repositories/local_medicine_store.dart';
import 'features/search/data/repositories/seeded_medicine_store.dart';
import 'features/search/data/sync/pending_write_queue.dart';
import 'features/search/presentation/providers/medicine_provider.dart';
import 'features/reports/data/repositories/reports_repository.dart';
import 'features/reports/data/repositories/reports_repository_impl.dart';
import 'features/reports/presentation/providers/reports_provider.dart';
import 'features/dashboard/presentation/providers/notification_provider.dart';
import 'features/dashboard/presentation/providers/notification_repository.dart';
import 'features/finder/presentation/providers/feature_search_provider.dart';
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
        // The operating system's answer about the network, read once for the
        // whole app. Firestore will take tens of seconds of its own backoff to
        // admit a lost connection; this is what puts the banner up before then.
        Provider<ConnectionSource>(create: (_) => PlatformConnectionSource()),
        Provider<AuthRepository>(create: (_) => FirebaseAuthRepository()),
        // One Firestore handle for the whole app. FirebaseFirestore.instance is
        // already a singleton, so this is a shared handle rather than a shared
        // database, and every store can be built from the same object.
        Provider<FirebaseFirestore>(create: (_) => FirebaseFirestore.instance),
        Provider<OfflineSession>(
          create: (_) => StoredOfflineSession(
            readStorage: () async => (await SharedPreferences.getInstance())
                .getString('offlineMode'),
            writeStorage: (value) async =>
                (await SharedPreferences.getInstance()).setString(
                  'offlineMode',
                  value ?? '',
                ),
          ),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(
            ctx.read<AuthRepository>(),
            offlineSession: ctx.read<OfflineSession>(),
          ),
        ),
        // Above the router, so the price list outlives a tab switch. Built from a
        // factory because the store is scoped to a user id, and signing in as
        // somebody else has to give it a different one.
        //
        // Wrapped in SeededMedicineStore so the bundled price list is on screen
        // before any network call finishes, and so a brand new account seeds
        // itself instead of sitting empty until somebody runs
        // tool/seed_firestore.dart from a laptop.
        ChangeNotifierProvider<MedicineProvider>(
          create: (ctx) {
            final firestore = ctx.read<FirebaseFirestore>();
            return MedicineProvider(
              auth: ctx.read<AuthProvider>(),
              storeFor: (uid) {
                if (uid == AuthProvider.offlineUserId) {
                  return LocalMedicineStore();
                }
                return SeededMedicineStore(
                  remote: FirestoreMedicineStore(
                    firestore: firestore,
                    uid: uid,
                    connection: ctx.read<ConnectionSource>(),
                    queue: _queueFor(uid),
                  ),
                );
              },
            );
          },
        ),
        // Offline has nowhere to put a finished order, so history is kept in
        // memory for the session. One instance for the whole app: the provider
        // asks for a repository per sale, and one built per sale would leave
        // the screen empty after every order.
        Provider<LocalOrderHistoryRepository>(
          create: (_) => LocalOrderHistoryRepository(),
          dispose: (_, store) => store.dispose(),
        ),
        // Where a user's order history lives, decided once. The cart and the
        // dashboard both need it and neither owns it: offline a finished order
        // has nowhere to go, so history stays in memory, while online it is in
        // Firestore under the user's id.
        Provider<OrderHistoryRepositoryFactory>(
          create: (ctx) => (uid) {
            if (uid == AuthProvider.offlineUserId) {
              return ctx.read<LocalOrderHistoryRepository>();
            }
            return FirestoreOrderHistoryRepository(
              firestore: ctx.read<FirebaseFirestore>(),
              uid: uid,
            );
          },
        ),
        // Above the router, so the order outlives a tab switch -- and, with the
        // draft store, outlives the app closing. Constructed against auth so
        // signing out empties it and signing back in picks the basket up again.
        ChangeNotifierProvider<OrderProvider>(
          create: (ctx) => OrderProvider(
            auth: ctx.read<AuthProvider>(),
            catalogue: ctx.read<MedicineProvider>(),
            draftFor: (uid) {
              if (uid == AuthProvider.offlineUserId) {
                return LocalOrderDraftStore();
              }
              return FirestoreOrderDraftStore(
                firestore: ctx.read<FirebaseFirestore>(),
                uid: uid,
              );
            },
            historyFor: ctx.read<OrderHistoryRepositoryFactory>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => FeatureSearchProvider()),
        Provider<GoRouter>(
          create: (ctx) =>
              createAppRouter(refreshListenable: ctx.read<AuthProvider>()),
          dispose: (_, router) => router.dispose(),
        ),
        // The Orders tab's writes. Reading the orders themselves is the screen's
        // own business, but approving or rejecting goes through a provider so the
        // status change and the reload after it are one unit rather than two
        // things a button has to remember to do.
        //
        // Built against the same per-user factory as the cart, so Orders approves
        // into the history the rest of the app reads rather than into a second
        // store scoped to whichever user happened to sign in first.
        ChangeNotifierProvider<OrdersProvider>(
          create: (ctx) => OrdersProvider(
            historyFactory: () => ctx.read<OrderHistoryRepositoryFactory>()(
              ctx.read<AuthProvider>().user?.id ?? '',
            ),
          ),
        ),


        // Reports repository and provider for the Reports tab.
        Provider<ReportsRepository>(
          create: (ctx) => ReportsRepositoryImpl(
            medicineProvider: ctx.read<MedicineProvider>(),
            historyFactory: () => ctx.read<OrderHistoryRepositoryFactory>()(
              ctx.read<AuthProvider>().user?.id ?? '',
            ),
          ),
        ),
        ChangeNotifierProvider<ReportsProvider>(
          create: (ctx) => ReportsProvider(
            repository: ctx.read<ReportsRepository>(),
          ),
        ),
        Provider<NotificationRepository>(
          create: (_) => InMemoryNotificationRepository(),
        ),
        ChangeNotifierProvider<NotificationsProvider>(
          create: (ctx) => NotificationsProvider(
            repository: ctx.read<NotificationRepository>(),
          ),
        ),
        ChangeNotifierProvider<NotificationFilterProvider>(
          create: (_) => NotificationFilterProvider(),
        ),
      ],
      child: const App(),
    );
  }

  /// The app's own record of writes the server has not confirmed, for one
  /// account.
  ///
  /// Kept in preferences under a key namespaced by uid: a shared counter tablet
  /// is signed in and out all day, and one pharmacist's unsent stock counts must
  /// not turn up as another's.
  ///
  /// A read failure is not fatal -- [StoredPendingWriteQueue] falls back to an
  /// empty queue, which costs the second copy of each write and nothing else,
  /// because Firestore's own queue is still behind it.
  static PendingWriteQueue _queueFor(String uid) {
    final key = 'pendingWrites/$uid';
    return StoredPendingWriteQueue(
      readStorage: () async =>
          (await SharedPreferences.getInstance()).getString(key),
      writeStorage: (value) async =>
          (await SharedPreferences.getInstance()).setString(key, value),
    );
  }
}
