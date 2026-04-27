import 'package:flutter/foundation.dart';
import '../../data/app_data.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _items.fold(0, (sum, item) => sum + item.total);

  void addItem(ProductItem product, [int quantity = 1]) {
    if (product.productId == null) return;

    final index = _items.indexWhere((item) => item.productId == product.productId);

    if (index != -1) {
      _items[index].quantity += quantity;
    } else {
      _items.add(CartItem(
        farmerId: product.farmerId ?? '',
        productId: product.productId!,
        name: product.name,
        farm: product.farm,
        price: product.price,
        unit: product.unit,
        imageUrl: product.imageUrl,
        quantity: quantity,
      ));
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index != -1) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
