import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Supabase client. A provider so tests can swap it out.
final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
