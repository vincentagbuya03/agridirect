import 'package:supabase_flutter/supabase_flutter.dart';

/// Quick script to verify Supabase connection
Future<void> main() async {
  print('🔵 Verifying Supabase connection...');

  const supabaseUrl = 'https://ywfppgarzyksacgbesme.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3ZnBwZ2Fyenlrc2FjZ2Jlc21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMjcsImV4cCI6MjA4NzM0NzMyN30.aX1HIacJsHV8gU-9tGONnDpucE9vePWOrJbgMR4fSzs';

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

    print('✅ Supabase initialized successfully');

    final client = Supabase.instance.client;

    // Test a simple query
    final response = await client.from('users').select('count').count();
    print('✅ Connection verified - Database is reachable');
    print('📊 Current user count: $response');
  } catch (e) {
    print('❌ Error connecting to Supabase: $e');
    rethrow;
  }
}
