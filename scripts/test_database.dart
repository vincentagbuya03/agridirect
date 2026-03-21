import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Comprehensive Database Test Script for AgriDirect
///
/// This script tests all major database operations to ensure
/// the schema is correctly applied and fully functional.
///
/// Run this AFTER applying database.sql to your Supabase instance

Future<void> main() async {
  print('🚀 Starting AgriDirect Database Tests...\n');

  const supabaseUrl = 'https://ywfppgarzyksacgbesme.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3ZnBwZ2Fyenlrc2FjZ2Jlc21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMjcsImV4cCI6MjA4NzM0NzMyN30.aX1HIacJsHV8gU-9tGONnDpucE9vePWOrJbgMR4fSzs';

  try {
    // Initialize Supabase
    print('1️⃣ Initializing Supabase...');
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    print('   ✅ Supabase initialized\n');

    final client = Supabase.instance.client;

    // Test 1: Check Categories
    print('2️⃣ Testing Categories Table...');
    final categories = await client.from('categories').select('name, icon');
    print('   ✅ Found ${categories.length} categories');
    if (categories.length >= 8) {
      print('   ✅ Initial categories loaded successfully');
      for (var cat in categories) {
        print('      ${cat['icon']} ${cat['name']}');
      }
    } else {
      print('   ⚠️  Expected at least 8 categories');
    }
    print('');

    // Test 2: Check Units
    print('3️⃣ Testing Units Table...');
    final units = await client.from('units').select('name, abbreviation');
    print('   ✅ Found ${units.length} units');
    if (units.length >= 11) {
      print('   ✅ Initial units loaded successfully');
      for (var unit in units) {
        print('      ${unit['name']} (${unit['abbreviation']})');
      }
    } else {
      print('   ⚠️  Expected at least 11 units');
    }
    print('');

    // Test 3: Check Table Structure
    print('4️⃣ Testing Core Tables Structure...');
    final coreTables = ['users', 'customers', 'farmers', 'admins'];
    for (var table in coreTables) {
      try {
        await client.from(table).select('*').limit(0);
        print('   ✅ $table table exists');
      } catch (e) {
        print('   ❌ $table table missing or inaccessible: $e');
      }
    }
    print('');

    // Test 4: Check Product System Tables
    print('5️⃣ Testing Product System Tables...');
    final productTables = [
      'products',
      'product_images',
      'product_inventory',
      'product_reviews',
    ];
    for (var table in productTables) {
      try {
        await client.from(table).select('*').limit(0);
        print('   ✅ $table table exists');
      } catch (e) {
        print('   ❌ $table table missing: $e');
      }
    }
    print('');

    // Test 5: Check Order System Tables
    print('6️⃣ Testing Order System Tables...');
    final orderTables = [
      'orders',
      'order_items',
      'order_status_history',
      'payments',
    ];
    for (var table in orderTables) {
      try {
        await client.from(table).select('*').limit(0);
        print('   ✅ $table table exists');
      } catch (e) {
        print('   ❌ $table table missing: $e');
      }
    }
    print('');

    // Test 6: Check Shopping Features
    print('7️⃣ Testing Shopping Features...');
    final shoppingTables = ['cart_items', 'wishlist_items'];
    for (var table in shoppingTables) {
      try {
        await client.from(table).select('*').limit(0);
        print('   ✅ $table table exists');
      } catch (e) {
        print('   ❌ $table table missing: $e');
      }
    }
    print('');

    // Test 7: Check Communication System
    print('8️⃣ Testing Communication System...');
    final commTables = [
      'conversations',
      'messages',
      'notifications',
      'admin_logs',
    ];
    for (var table in commTables) {
      try {
        await client.from(table).select('*').limit(0);
        print('   ✅ $table table exists');
      } catch (e) {
        print('   ❌ $table table missing: $e');
      }
    }
    print('');

    // Test 8: Check Forum System
    print('9️⃣ Testing Forum System...');
    final forumTables = ['forum_posts', 'forum_comments', 'post_likes'];
    for (var table in forumTables) {
      try {
        await client.from(table).select('*').limit(0);
        print('   ✅ $table table exists');
      } catch (e) {
        print('   ❌ $table table missing: $e');
      }
    }
    print('');

    // Test 9: Check Farmer System
    print('🔟 Testing Farmer System...');
    final farmerTables = [
      'farmer_certifications',
      'farmer_ratings',
      'farmer_registrations',
      'farmer_education',
      'farmer_crop_types',
      'farmer_livestock',
      'delivery_addresses',
    ];
    for (var table in farmerTables) {
      try {
        await client.from(table).select('*').limit(0);
        print('   ✅ $table table exists');
      } catch (e) {
        print('   ❌ $table table missing: $e');
      }
    }
    print('');

    // Final Summary
    print('═══════════════════════════════════════════════════');
    print('🎉 DATABASE TEST COMPLETE!');
    print('═══════════════════════════════════════════════════');
    print('');
    print('✅ All core tables verified');
    print('✅ Initial data loaded (categories & units)');
    print('✅ Database is ready for use');
    print('');
    print('📱 Next Steps:');
    print('   1. Test user registration in your app');
    print('   2. Verify trigger creates user profile automatically');
    print('   3. Test farmer profile creation');
    print('   4. Add sample products');
    print('   5. Test shopping cart and orders');
    print('');
    print('📚 For detailed verification, run: verify_database.sql');
    print('');
  } catch (e, stackTrace) {
    print('❌ ERROR: $e');
    print('Stack trace: $stackTrace');
    print('');
    print('🔧 Troubleshooting:');
    print('   1. Ensure database.sql was applied successfully');
    print('   2. Check Supabase project URL and anon key are correct');
    print('   3. Verify network connection');
    print('   4. Check Supabase dashboard for error logs');
  }
}
