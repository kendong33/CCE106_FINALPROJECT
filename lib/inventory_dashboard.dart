import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'crud_service.dart';
import 'auth_service.dart';

class InventoryDashboard extends StatefulWidget {
  const InventoryDashboard({super.key});

  @override
  State<InventoryDashboard> createState() => _InventoryDashboardState();
}

class _InventoryDashboardState extends State<InventoryDashboard> {
  final CrudService _crudService = CrudService();

  // Primary brand color
  final Color primaryColor = const Color(0xFF8B1D1D);

  void _showAddDialog() {
    final nameController = TextEditingController();
    final stockController = TextEditingController();
    final unitController = TextEditingController();
    final thresholdController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Add New Ingredient', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Ingredient Name',
                      labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor.withOpacity(0.3))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: stockController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Starting Quantity',
                      labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor.withOpacity(0.3))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: unitController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Unit (e.g., kg, liters)',
                      labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor.withOpacity(0.3))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: thresholdController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Low Stock Threshold',
                      labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor.withOpacity(0.3))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final stock = double.tryParse(stockController.text.trim()) ?? 0.0;
                  final unit = unitController.text.trim();
                  final threshold = double.tryParse(thresholdController.text.trim()) ?? 0.0;
                  
                  await _crudService.addIngredient(name, stock, unit, threshold);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showRestockDialog(Ingredient ingredient) {
    final nameController = TextEditingController(text: ingredient.name);
    final stockController = TextEditingController(text: ingredient.currentStock.toString());
    final unitController = TextEditingController(text: ingredient.unit);
    final thresholdController = TextEditingController(text: ingredient.lowStockThreshold.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Edit ${ingredient.name}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Ingredient Name',
                      labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor.withOpacity(0.3))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: stockController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Current Quantity',
                      labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor.withOpacity(0.3))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: unitController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Unit (e.g., kg, liters)',
                      labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor.withOpacity(0.3))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: thresholdController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Low Stock Threshold',
                      labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor.withOpacity(0.3))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                await _crudService.deleteIngredient(ingredient.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Delete Item', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final stock = double.tryParse(stockController.text.trim()) ?? 0.0;
                  final unit = unitController.text.trim();
                  final threshold = double.tryParse(thresholdController.text.trim()) ?? 0.0;
                  await _crudService.updateIngredientDetails(ingredient.id, name, unit, threshold);
                  await _crudService.updateStockQuantity(ingredient.id, stock);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Inventory Dashboard'),
      ),
      body: StreamBuilder<List<Ingredient>>(
        stream: _crudService.getInventoryStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          final ingredients = snapshot.data ?? [];

          if (ingredients.isEmpty) {
            return Center(
              child: Text(
                'No items in inventory.',
                style: TextStyle(color: primaryColor.withOpacity(0.6), fontSize: 18.0),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: ingredients.length,
            itemBuilder: (context, index) {
              final ingredient = ingredients[index];
              final isLowStock = ingredient.currentStock <= ingredient.lowStockThreshold;

              return Card(
                color: isLowStock ? const Color(0xFFFFEBEE) : Colors.white,
                elevation: 3,
                shadowColor: primaryColor.withOpacity(0.2),
                margin: const EdgeInsets.only(bottom: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  side: BorderSide(
                    color: isLowStock ? Colors.red.withOpacity(0.5) : primaryColor.withOpacity(0.1),
                    width: 1,
                  )
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  title: Text(
                    ingredient.name,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4.0),
                      Text(
                        'Stock: ${ingredient.currentStock} ${ingredient.unit}',
                        style: const TextStyle(color: Colors.black87, fontSize: 16.0),
                      ),
                      if (isLowStock)
                        Container(
                          margin: const EdgeInsets.only(top: 8.0),
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: const Text(
                            'LOW STOCK - REPLENISH',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Icon(Icons.edit, color: primaryColor),
                  onTap: () => _showRestockDialog(ingredient),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
