import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    _supabase.auth.onAuthStateChange.listen((data) async {
      if (data.session == null) {
        _customerId = null;
        await loadCart();
      } else {
        await _mergeGuestCartToDb();
        await loadCart();
      }
    });
    await loadCart();
  }

  Future<void> _mergeGuestCartToDb() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guestCartJson = prefs.getString('guest_cart');
      if (guestCartJson != null && guestCartJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(guestCartJson);
        final guestItems = decoded.map((item) => CartItem.fromJson(item)).toList();
        
        final customerId = await _getCustomerId();
        final currentUserId = _supabase.auth.currentUser?.id;
        
        if (customerId != null) {
          for (var item in guestItems) {
            if (currentUserId != null && item.farmerId == currentUserId) {
              continue;
            }
            
            final existing = await _supabase
                .from('cart_items')
                .select('quantity')
                .eq('customer_id', customerId)
                .eq('product_id', item.productId)
                .maybeSingle();
                
            int newQty = item.quantity;
            if (existing != null) {
              newQty += (existing['quantity'] as num).toInt();
            }
            
            await _supabase.from('cart_items').upsert({
              'customer_id': customerId,
              'product_id': item.productId,
              'quantity': newQty,
              'updated_at': DateTime.now().toIso8601String(),
            }, onConflict: 'customer_id,product_id');
          }
        }
        await prefs.remove('guest_cart');
      }
    } catch (e) {
      debugPrint('[Cart] Error merging guest cart: $e');
    }
  }

  Future<void> _saveGuestCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_items.map((item) => item.toJson()).toList());
      await prefs.setString('guest_cart', jsonStr);
    } catch (e) {
      debugPrint('[Cart] Error saving guest cart: $e');
    }
  }

  Future<void> _loadGuestCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('guest_cart');
      _items.clear();
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _items.addAll(decoded.map((item) => CartItem.fromJson(item)));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Cart] Error loading guest cart: $e');
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
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      await _loadGuestCart();
      return;
    }

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

    final currentUserId = _supabase.auth.currentUser?.id;

    if (currentUserId != null && product.farmerId == currentUserId) {
      debugPrint('[Cart] 🛡️ Blocked attempt to add own product: ${product.productId}');
      return;
    }

    final index = _items.indexWhere((item) => item.productId == product.productId);

    if (index != -1) {
      _items[index].quantity += quantity;
      if (currentUserId != null) {
        final customerId = await _getCustomerId();
        if (customerId != null) {
          await _supabase.from('cart_items').upsert({
            'customer_id': customerId,
            'product_id': product.productId!,
            'quantity': _items[index].quantity,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'customer_id,product_id');
        }
      } else {
        await _saveGuestCart();
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

      if (currentUserId != null) {
        final customerId = await _getCustomerId();
        if (customerId != null) {
          await _supabase.from('cart_items').upsert({
            'customer_id': customerId,
            'product_id': product.productId!,
            'quantity': quantity,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'customer_id,product_id');
        }
      } else {
        await _saveGuestCart();
      }
    }
    notifyListeners();
  }

  Future<void> removeItem(String productId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    _items.removeWhere((item) => item.productId == productId);
    
    if (currentUserId != null) {
      final customerId = await _getCustomerId();
      if (customerId != null) {
        await _supabase.from('cart_items')
            .delete()
            .eq('customer_id', customerId)
            .eq('product_id', productId);
      }
    } else {
      await _saveGuestCart();
    }
    notifyListeners();
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    final index = _items.indexWhere((item) => item.productId == productId);
    
    if (index != -1) {
      if (quantity <= 0) {
        _items.removeAt(index);
        if (currentUserId != null) {
          final customerId = await _getCustomerId();
          if (customerId != null) {
            await _supabase.from('cart_items')
                .delete()
                .eq('customer_id', customerId)
                .eq('product_id', productId);
          }
        } else {
          await _saveGuestCart();
        }
      } else {
        _items[index].quantity = quantity;
        if (currentUserId != null) {
          final customerId = await _getCustomerId();
          if (customerId != null) {
            await _supabase.from('cart_items').update({
              'quantity': quantity,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('customer_id', customerId).eq('product_id', productId);
          }
        } else {
          await _saveGuestCart();
        }
      }
      notifyListeners();
    }
  }

  Future<void> clear() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    _items.clear();
    
    if (currentUserId != null) {
      final customerId = await _getCustomerId();
      if (customerId != null) {
        await _supabase.from('cart_items')
            .delete()
            .eq('customer_id', customerId);
      }
    } else {
      await _saveGuestCart();
    }
    notifyListeners();
  }

  Future<void> removeSelected() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    final selectedIds = _items.where((item) => item.isSelected).map((e) => e.productId).toList();
    
    _items.removeWhere((item) => item.isSelected);
    
    if (currentUserId != null) {
      final customerId = await _getCustomerId();
      if (customerId != null && selectedIds.isNotEmpty) {
        await _supabase.from('cart_items')
            .delete()
            .eq('customer_id', customerId)
            .inFilter('product_id', selectedIds);
      }
    } else {
      await _saveGuestCart();
    }
    notifyListeners();
  }
}
