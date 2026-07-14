import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'product_crud_service.dart';
import 'crud_service.dart';

class ProductManagementDashboard extends StatefulWidget {
  const ProductManagementDashboard({super.key});

  @override
  State<ProductManagementDashboard> createState() => _ProductManagementDashboardState();
}

class _ProductManagementDashboardState extends State<ProductManagementDashboard> {
  final ProductCrudService _productService = ProductCrudService();
  final CrudService _crudService = CrudService();
  final Color primaryColor = const Color(0xFF8B1D1D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Product Management'),
      ),
      body: StreamBuilder<List<Ingredient>>(
        stream: _crudService.getInventoryStream(),
        builder: (context, invSnapshot) {
          if (invSnapshot.hasError) {
            return Center(child: Text('Error: ${invSnapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (invSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          final inventoryItems = invSnapshot.data ?? [];

          return StreamBuilder<List<Product>>(
            stream: _productService.getProductsStream(),
            builder: (context, prodSnapshot) {
              if (prodSnapshot.hasError) {
                return Center(child: Text('Error: ${prodSnapshot.error}', style: const TextStyle(color: Colors.red)));
              }
              if (prodSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: primaryColor));
              }

              final products = prodSnapshot.data ?? [];

              if (products.isEmpty) {
                return Center(
                  child: Text(
                    'No menu items found.',
                    style: TextStyle(color: primaryColor.withOpacity(0.6), fontSize: 18.0),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  
                  // Map the ingredient IDs to displayable text
                  final reqStrings = product.ingredientsRequired.map((req) {
                    final amount = req['amount_needed'];
                    final ingId = req['ingredient_id'];
                    
                    final ingredient = inventoryItems.firstWhere(
                      (item) => item.id == ingId,
                      orElse: () => Ingredient(id: '', name: 'Unknown', currentStock: 0, unit: '', lowStockThreshold: 0),
                    );
                    
                    return '$amount${ingredient.unit} ${ingredient.name}';
                  }).join(', ');

                  return Card(
                    color: Colors.white,
                    elevation: 3,
                    shadowColor: primaryColor.withOpacity(0.2),
                    margin: const EdgeInsets.only(bottom: 12.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side: BorderSide(color: primaryColor.withOpacity(0.1), width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: TextStyle(color: primaryColor, fontSize: 18.0, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.black87, fontSize: 18.0, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => _EditProductDialog(
                                      product: product,
                                      inventoryItems: inventoryItems,
                                      productService: _productService,
                                      primaryColor: primaryColor,
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _productService.deleteProduct(product.id),
                              )
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Wrap(
                            spacing: 8.0,
                            children: [
                              Chip(
                                label: Text(
                                  reqStrings.isEmpty ? 'No recipe mapped' : 'Consumes: $reqStrings',
                                  style: const TextStyle(color: Colors.white, fontSize: 12.0),
                                ),
                                backgroundColor: primaryColor.withOpacity(0.8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<List<Ingredient>>(
        stream: _crudService.getInventoryStream(),
        builder: (context, snapshot) {
          final inventoryItems = snapshot.data ?? [];
          return FloatingActionButton(
            onPressed: () {
              if (inventoryItems.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please add inventory items before creating products.')),
                );
                return;
              }
              showDialog(
                context: context,
                builder: (context) => _AddProductDialog(
                  inventoryItems: inventoryItems,
                  productService: _productService,
                  primaryColor: primaryColor,
                ),
              );
            },
            backgroundColor: primaryColor,
            child: const Icon(Icons.add, color: Colors.white),
          );
        }
      ),
    );
  }
}

class IngredientFormRow {
  String? ingredientId;
  TextEditingController amountController;

  IngredientFormRow({this.ingredientId, required this.amountController});
}

class _AddProductDialog extends StatefulWidget {
  final List<Ingredient> inventoryItems;
  final ProductCrudService productService;
  final Color primaryColor;

  const _AddProductDialog({
    required this.inventoryItems,
    required this.productService,
    required this.primaryColor,
  });

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final List<IngredientFormRow> _rows = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    for (var row in _rows) {
      row.amountController.dispose();
    }
    super.dispose();
  }

  void _addIngredientRow() {
    setState(() {
      _rows.add(IngredientFormRow(amountController: TextEditingController()));
    });
  }

  void _removeIngredientRow(int index) {
    setState(() {
      _rows[index].amountController.dispose();
      _rows.removeAt(index);
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one ingredient.')));
      return;
    }

    if (_rows.any((r) => r.ingredientId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an ingredient for all rows.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final price = double.parse(_priceController.text.trim());
      
      final reqs = _rows.map((r) => {
        'ingredient_id': r.ingredientId,
        'amount_needed': double.parse(r.amountController.text.trim()),
      }).toList();

      await widget.productService.addProduct(name, price, reqs);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Add New Product', style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Product Name',
                    labelStyle: TextStyle(color: widget.primaryColor.withOpacity(0.7)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor.withOpacity(0.3))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor)),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Price',
                    labelStyle: TextStyle(color: widget.primaryColor.withOpacity(0.7)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor.withOpacity(0.3))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 24.0),
                Text('Recipe Items', style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold, fontSize: 16.0)),
                const SizedBox(height: 8.0),
                if (_rows.isEmpty)
                  Text('No ingredients mapped yet.', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
                
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    String unitLabel = 'Amount';
                    if (row.ingredientId != null) {
                       final matched = widget.inventoryItems.firstWhere(
                         (i) => i.id == row.ingredientId, 
                         orElse: () => Ingredient(id: '', name: '', currentStock: 0, unit: '', lowStockThreshold: 0)
                       );
                       if (matched.id.isNotEmpty) {
                         unitLabel = 'Amount (${matched.unit})';
                       }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: row.ingredientId,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: 'Ingredient',
                                labelStyle: TextStyle(color: widget.primaryColor.withOpacity(0.7)),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor.withOpacity(0.3))),
                                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor)),
                              ),
                              items: widget.inventoryItems.map((ing) {
                                return DropdownMenuItem(
                                  value: ing.id,
                                  child: Text(ing.name, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  row.ingredientId = val;
                                });
                              },
                              validator: (val) => val == null ? 'Select' : null,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: row.amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: unitLabel,
                                labelStyle: TextStyle(color: widget.primaryColor.withOpacity(0.7), fontSize: 12),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor.withOpacity(0.3))),
                                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor)),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Req';
                                if (double.tryParse(value) == null) return 'Err';
                                return null;
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () => _removeIngredientRow(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12.0),
                OutlinedButton.icon(
                  onPressed: _addIngredientRow,
                  icon: Icon(Icons.add, color: widget.primaryColor),
                  label: Text('Add Ingredient', style: TextStyle(color: widget.primaryColor)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: widget.primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(backgroundColor: widget.primaryColor, foregroundColor: Colors.white),
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Text('Save'),
        ),
      ],
    );
  }
}

class _EditProductDialog extends StatefulWidget {
  final Product product;
  final List<Ingredient> inventoryItems;
  final ProductCrudService productService;
  final Color primaryColor;

  const _EditProductDialog({
    required this.product,
    required this.inventoryItems,
    required this.productService,
    required this.primaryColor,
  });

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late List<IngredientFormRow> _rows;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(text: widget.product.price.toString());
    _rows = widget.product.ingredientsRequired.map((req) {
      return IngredientFormRow(
        ingredientId: req['ingredient_id'] as String,
        amountController: TextEditingController(text: req['amount_needed'].toString()),
      );
    }).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    for (var row in _rows) {
      row.amountController.dispose();
    }
    super.dispose();
  }

  void _addIngredientRow() {
    setState(() {
      _rows.add(IngredientFormRow(amountController: TextEditingController()));
    });
  }

  void _removeIngredientRow(int index) {
    setState(() {
      _rows[index].amountController.dispose();
      _rows.removeAt(index);
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one ingredient.')));
      return;
    }

    if (_rows.any((r) => r.ingredientId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an ingredient for all rows.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final price = double.parse(_priceController.text.trim());
      
      final reqs = _rows.map((r) => {
        'ingredient_id': r.ingredientId,
        'amount_needed': double.parse(r.amountController.text.trim()),
      }).toList();

      await widget.productService.updateProduct(widget.product.id, name, price, reqs);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Edit Product', style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Product Name',
                    labelStyle: TextStyle(color: widget.primaryColor.withOpacity(0.7)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor.withOpacity(0.3))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor)),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Price',
                    labelStyle: TextStyle(color: widget.primaryColor.withOpacity(0.7)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor.withOpacity(0.3))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 24.0),
                Text('Recipe Items', style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold, fontSize: 16.0)),
                const SizedBox(height: 8.0),
                if (_rows.isEmpty)
                  Text('No ingredients mapped yet.', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
                
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    String unitLabel = 'Amount';
                    if (row.ingredientId != null) {
                       final matched = widget.inventoryItems.firstWhere(
                         (i) => i.id == row.ingredientId, 
                         orElse: () => Ingredient(id: '', name: '', currentStock: 0, unit: '', lowStockThreshold: 0)
                       );
                       if (matched.id.isNotEmpty) {
                         unitLabel = 'Amount (${matched.unit})';
                       }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: row.ingredientId,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: 'Ingredient',
                                labelStyle: TextStyle(color: widget.primaryColor.withOpacity(0.7)),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor.withOpacity(0.3))),
                                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor)),
                              ),
                              items: widget.inventoryItems.map((ing) {
                                return DropdownMenuItem(
                                  value: ing.id,
                                  child: Text(ing.name, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  row.ingredientId = val;
                                });
                              },
                              validator: (val) => val == null ? 'Select' : null,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: row.amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: unitLabel,
                                labelStyle: TextStyle(color: widget.primaryColor.withOpacity(0.7), fontSize: 12),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor.withOpacity(0.3))),
                                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.primaryColor)),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Req';
                                if (double.tryParse(value) == null) return 'Err';
                                return null;
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () => _removeIngredientRow(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12.0),
                OutlinedButton.icon(
                  onPressed: _addIngredientRow,
                  icon: Icon(Icons.add, color: widget.primaryColor),
                  label: Text('Add Ingredient', style: TextStyle(color: widget.primaryColor)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: widget.primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(backgroundColor: widget.primaryColor, foregroundColor: Colors.white),
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Text('Save'),
        ),
      ],
    );
  }
}
