import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'lib/shared/services/core/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  final client = SupabaseConfig.client;

  final productId = '61fd9358-dc77-488d-964c-7aae54396543';
  print('Querying $productId...');
  try {
    final response = await client
        .from('v_products')
        .select()
        .eq('product_id', productId)
        .maybeSingle();
    print('Response: $response');
  } catch (e) {
    print('Error: $e');
  }
}
