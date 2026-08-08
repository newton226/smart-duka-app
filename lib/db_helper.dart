class DBHelper {
  static final List<Map<String, dynamic>> _storage = [];

  static Future<void> addProduct(Map<String, dynamic> product) async {
    _storage.insert(0, product);
  }

  static Future<List<Map<String, dynamic>>> getProducts(String query) async {
    if (query.trim().isEmpty) return List.from(_storage);

    final q = query.toLowerCase();
    return _storage.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final kw = (p['keywords'] ?? '').toString().toLowerCase();
      return name.contains(q) || kw.contains(q);
    }).toList();
  }

  static Future<void> reduceStock(int id, int qtySold) async {
    final index = _storage.indexWhere((p) => p['id'] == id);
    if (index != -1) {
      int currentStock = _storage[index]['stock'] ?? 0;
      int newStock = currentStock - qtySold;
      _storage[index]['stock'] = newStock < 0 ? 0 : newStock;
    }
  }
}
