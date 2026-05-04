import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/app_data.dart';
import '../core/supabase_data_service.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal() {
    _initialize();
  }

  final List<CartItem> _items = [];
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _customerId;

  List<CartItem> get items => List.unmodifiable(_items);

  List<CartItem> get selectedItems => _items.where((item) => item.isSelected).toList();

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _items.fold(0, (sum, item) => sum + (item.isSelected ? item.total : 0));

  bool get isAllSelected => _items.isNotEmpty && _items.every((item) => item.isSelected);

  Future<void> _initialize() async {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session == null) {
        _items.clear();
        _customerId = null;
        notifyListeners();
      } else {
        loadCart();
      }
    });
    if (_supabase.auth.currentUser != null) {
      await loadCart();
    }
  }

  Future<String?> _getCustomerId() async {
    if (_customerId != null) return _customerId;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('customers')
          .select('customer_id')
          .eq('user_id', userId)
          .maybeSingle();
      
      _customerId = response?['customer_id'] as String?;
      return _customerId;
    } catch (e) {
      debugPrint('Error getting customer_id: $e');
      return null;
    }
  }

  Future<void> loadCart() async {
    final customerId = await _getCustomerId();
    if (customerId == null) return;

    try {
      final response = await _supabase
          .from('cart_items')
          .select()
          .eq('customer_id', customerId);
      
      final dbItems = response as List;
      final Map<String, CartItem> uniqueItems = {};

      for (var dbItem in dbItems) {
        final productId = dbItem['product_id'] as String;
        
        // If we already have this product in our map, just update the quantity (if larger)
        if (uniqueItems.containsKey(productId)) {
          final newQty = (dbItem['quantity'] as num).toInt();
          if (newQty > uniqueItems[productId]!.quantity) {
            uniqueItems[productId]!.quantity = newQty;
          }
          continue;
        }

        final product = await SupabaseDataService().getProductById(productId);
        
        if (product != null) {
          uniqueItems[productId] = CartItem(
            farmerId: product.farmerId ?? '',
            productId: productId,
            name: product.name,
            farm: product.farm,
            price: product.price,
            unit: product.unit,
            imageUrl: product.imageUrl,
            quantity: (dbItem['quantity'] as num).toInt(),
          );
        }
      }

      _items.clear();
      _items.addAll(uniqueItems.values);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  void toggleAll(bool selected) {
    for (var item in _items) {
      item.isSelected = selected;
    }
    notifyListeners();
  }

  void toggleSelection(String productId) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index != -1) {
      _items[index].isSelected = !_items[index].isSelected;
      notifyListeners();
    }
  }

  Future<void> addItem(ProductItem product, [int quantity = 1]) async {
    if (product.productId == null) return;

    final customerId = await _getCustomerId();
    final currentUserId = _supabase.auth.currentUser?.id;

    // Safety net: Prevent adding own product to cart
    if (currentUserId != null && product.farmerId == currentUserId) {
      debugPrint('[Cart] 🛡️ Blocked attempt to add own product: ${product.productId}');
      return;
    }

    final index = _items.indexWhere((item) => item.productId == product.productId);

    if (index != -1) {
      _items[index].quantity += quantity;
      if (customerId != null) {
        await _supabase.from('cart_items').upsert({
          'customer_id': customerId,
          'product_id': product.productId!,
          'quantity': _items[index].quantity,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'customer_id,product_id');
      }
    } else {
      final newItem = CartItem(
        farmerId: product.farmerId ?? '',
        productId: product.productId!,
        name: product.name,
        farm: product.farm,
        price: product.price,
        unit: product.unit,
        imageUrl: product.imageUrl,
        quantity: quantity,
      );
      _items.add(newItem);

      if (customerId != null) {
        await _supabase.from('cart_items').upsert({
          'customer_id': customerId,
          'product_id': product.productId!,
          'quantity': quantity,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'customer_id,product_id');
      }
    }
    notifyListeners();
  }

  Future<void> removeItem(String productId) async {
    final customerId = await _getCustomerId();
    _items.removeWhere((item) => item.productId == productId);
    
    if (customerId != null) {
      await _supabase.from('cart_items')
          .delete()
          .eq('customer_id', customerId)
          .eq('product_id', productId);
    }
    notifyListeners();
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    final customerId = await _getCustomerId();
    final index = _items.indexWhere((item) => item.productId == productId);
    
    if (index != -1) {
      if (quantity <= 0) {
        _items.removeAt(index);
        if (customerId != null) {
          await _supabase.from('cart_items')
              .delete()
              .eq('customer_id', customerId)
              .eq('product_id', productId);
        }
      } else {
        _items[index].quantity = quantity;
        if (customerId != null) {
          await _supabase.from('cart_items').update({
            'quantity': quantity,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('customer_id', customerId).eq('product_id', productId);
        }
      }
      notifyListeners();
    }
  }

  Future<void> clear() async {
    final customerId = await _getCustomerId();
    _items.clear();
    
    if (customerId != null) {
      await _supabase.from('cart_items')
          .delete()
          .eq('customer_id', customerId);
    }
    notifyListeners();
  }

  Future<void> removeSelected() async {
    final customerId = await _getCustomerId();
    final selectedIds = _items.where((item) => item.isSelected).map((e) => e.productId).toList();
    
    _items.removeWhere((item) => item.isSelected);
    
    if (customerId != null && selectedIds.isNotEmpty) {
      await _supabase.from('cart_items')
          .delete()
          .eq('customer_id', customerId)
          .inFilter('product_id', selectedIds);
    }
    notifyListeners();
  }
}
