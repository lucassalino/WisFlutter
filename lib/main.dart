import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );
  await initializeDateFormatting('pt');

  runApp(const ProviderScope(child: WisApp()));
}

class WisApp extends ConsumerWidget {
  const WisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'WIS — Worship In Sync',
      debugShowCheckedModeBanner: false,
      theme: WisTheme.dark,
      darkTheme: WisTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
