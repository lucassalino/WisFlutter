/// Supabase project shared with the existing WIS web app (ServiceFlow) —
/// this app consumes the same backend, it does not stand up a new one.
///
/// Overridable at build time with:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ikhxbczktmwkeglomgrv.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_iunLTuQ_QUqbO98P_XaM5g_ia-9-hts',
  );
}
