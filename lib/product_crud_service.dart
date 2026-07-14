import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final List<Map<String, dynamic>> ingredientsRequired;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.ingredientsRequired,
  });

  factory Product.fromDocument(DocumentSnapshot doc) {
    return Product(
      id: doc.id,
      name: doc['name'] as String,
      price: (doc['price'] as num).toDouble(),
      ingredientsRequired: List<Map<String, dynamic>>.from(doc['ingredients_required'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'ingredients_required': ingredientsRequired,
    };
  }
}

class ProductCrudService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Product>> getProductsStream() {
    return _firestore.collection('products').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Product.fromDocument(doc)).toList();
    });
  }

  Future<void> addProduct(String name, double price, List<Map<String, dynamic>> ingredientsRequired) async {
    await _firestore.collection('products').add({
      'name': name,
      'price': price,
      'ingredients_required': ingredientsRequired,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProduct(String id, String name, double price, List<Map<String, dynamic>> ingredientsRequired) async {
    await _firestore.collection('products').doc(id).update({
      'name': name,
      'price': price,
      'ingredients_required': ingredientsRequired,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String id) async {
    await _firestore.collection('products').doc(id).delete();
  }
}
