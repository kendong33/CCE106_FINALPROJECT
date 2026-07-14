import 'package:cloud_firestore/cloud_firestore.dart';

class Ingredient {
  final String id;
  final String name;
  final double currentStock;
  final String unit;
  final double lowStockThreshold;

  Ingredient({
    required this.id,
    required this.name,
    required this.currentStock,
    required this.unit,
    required this.lowStockThreshold,
  });

  factory Ingredient.fromDocument(DocumentSnapshot doc) {
    return Ingredient(
      id: doc.id,
      name: doc['name'] as String,
      currentStock: (doc['current_stock'] as num).toDouble(),
      unit: doc['unit'] as String,
      lowStockThreshold: (doc['low_stock_threshold'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'current_stock': currentStock,
      'unit': unit,
      'low_stock_threshold': lowStockThreshold,
    };
  }
}

class CrudService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Ingredient>> getInventoryStream() {
    return _firestore.collection('inventory').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Ingredient.fromDocument(doc)).toList();
    });
  }

  Future<void> addIngredient(String name, double currentStock, String unit, double threshold) async {
    await _firestore.collection('inventory').add({
      'name': name,
      'current_stock': currentStock,
      'unit': unit,
      'low_stock_threshold': threshold,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStockQuantity(String id, double newQuantity) async {
    await _firestore.collection('inventory').doc(id).update({
      'current_stock': newQuantity,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateIngredientDetails(String id, String name, String unit, double threshold) async {
    await _firestore.collection('inventory').doc(id).update({
      'name': name,
      'unit': unit,
      'low_stock_threshold': threshold,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteIngredient(String id) async {
    await _firestore.collection('inventory').doc(id).delete();
  }
}
