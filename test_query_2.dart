import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/shared/services/core/supabase_config.dart';

void main() async {
  await SupabaseConfig.initialize();
  final supabase = SupabaseConfig.client;

  try {
    final response = await supabase
        .from('order_items')
        .select('*, products(name, products:product_images(image_url))')
        .limit(1);
    print('Success: $response');
  } catch (e) {
    print('Error: $e');
  }
}
