import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/router/router.dart';
import 'core/theme.dart';
import 'core/unsaved_changes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  installBeforeUnloadGuard();
  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  runApp(
    // Screens show errors with a "Try again" button instead of retrying silently.
    ProviderScope(retry: (_, _) => null, child: const AdminApp()),
  );
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Avanilands Admin',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Missing SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY.\n'
            'Run with --dart-define-from-file=env/local.json',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
