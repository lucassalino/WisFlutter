import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The shared Supabase client. Initialized once in `main.dart` via
/// `Supabase.initialize` before this provider is first read.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Live stream of Supabase auth state changes (sign in/out, token refresh).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// The currently authenticated Supabase user, or null when signed out.
/// Rebuilds whenever [authStateChangesProvider] emits.
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.value?.session?.user ??
      ref.read(supabaseClientProvider).auth.currentUser;
});
