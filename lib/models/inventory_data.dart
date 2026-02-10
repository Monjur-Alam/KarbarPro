class InventoryData {
  final String itemName;
  final int quantity;
  final double price;
  final DateTime timestamp;

  InventoryData({
    required this.itemName,
    required this.quantity,
    required this.price,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // Create InventoryData from JSON
  factory InventoryData.fromJson(Map<String, dynamic> json) {
    return InventoryData(
      itemName: json['itemName'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  // Convert InventoryData to JSON
  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'quantity': quantity,
      'price': price,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'InventoryData(itemName: $itemName, quantity: $quantity, price: $price, timestamp: $timestamp)';
  }
}

// Sample inventory data for demonstration
class InventoryDataHelper {
  static List<InventoryData> getSampleData() {
    return [
      InventoryData(
        itemName: 'Rice (1kg)',
        quantity: 50,
        price: 65.0,
      ),
      InventoryData(
        itemName: 'Sugar (1kg)',
        quantity: 30,
        price: 85.0,
      ),
      InventoryData(
        itemName: 'Cooking Oil (1L)',
        quantity: 25,
        price: 180.0,
      ),
      InventoryData(
        itemName: 'Lentils (1kg)',
        quantity: 40,
        price: 120.0,
      ),
      InventoryData(
        itemName: 'Tea (250g)',
        quantity: 60,
        price: 150.0,
      ),
    ];
  }

  static Map<String, dynamic> getInventoryReport() {
    final items = getSampleData();
    return {
      'shopName': 'Amar Dokan',
      'reportDate': DateTime.now().toIso8601String(),
      'totalItems': items.length,
      'inventory': items.map((item) => item.toJson()).toList(),
    };
  }
}
