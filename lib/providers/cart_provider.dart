import 'package:flutter/foundation.dart';
import '../models/product.dart';

class CartEntry {
  final Product product;
  int qty;

  CartEntry({required this.product, this.qty = 1});

  double get lineTotal => product.price * qty;
}

class CartProvider extends ChangeNotifier {
  /// key = product.id
  final Map<String, CartEntry> _lines = {};

  List<CartEntry> get lines => _lines.values.toList(growable: false);

  int get totalQty => _lines.values.fold(0, (sum, e) => sum + e.qty);

  double get totalPrice =>
      _lines.values.fold(0.0, (sum, e) => sum + e.lineTotal);

  bool get isEmpty => _lines.isEmpty;

  void add(Product p, {int qty = 1}) {
    if (_lines.containsKey(p.id)) {
      _lines[p.id]!.qty += qty;
    } else {
      _lines[p.id] = CartEntry(product: p, qty: qty);
    }
    notifyListeners();
  }

  void increment(String productId) {
    if (_lines.containsKey(productId)) {
      _lines[productId]!.qty++;
      notifyListeners();
    }
  }

  void decrement(String productId) {
    if (!_lines.containsKey(productId)) return;
    final e = _lines[productId]!;
    if (e.qty > 1) {
      e.qty--;
    } else {
      _lines.remove(productId);
    }
    notifyListeners();
  }

  void remove(String productId) {
    _lines.remove(productId);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}
