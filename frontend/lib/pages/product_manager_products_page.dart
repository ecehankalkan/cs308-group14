import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/product_admin_service.dart';

const _dark = Color(0xFF8D7B68);
const _medium = Color(0xFFA4907C);
const _taupe = Color(0xFFC8B6A6);
const _cream = Color(0xFFF1DEC9);
const _offWhite = Color(0xFFFAF5EF);

class ProductManagerProductsPage extends StatefulWidget {
  const ProductManagerProductsPage({super.key});

  @override
  State<ProductManagerProductsPage> createState() => _ProductManagerProductsPageState();
}

class _ProductManagerProductsPageState extends State<ProductManagerProductsPage> {
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _loading = true);
    final products = await ProductAdminService.fetchAllProducts();
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  Future<void> _toggleProductStatus(Product product, bool isActive) async {
    // Optimistic UI Update: update locally first
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index == -1) return;
    
    setState(() {
      _products[index] = product.copyWith(isActive: isActive);
    });

    final result = await ProductAdminService.updateProductStatus(product.id, isActive);
    
    if (result == 'success') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} is now ${isActive ? 'active' : 'inactive'}'),
            backgroundColor: _dark,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Revert if it fails
      if (mounted) {
        setState(() {
          _products[index] = product.copyWith(isActive: !isActive);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update product status: $result'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final stockController = TextEditingController();
    final modelController = TextEditingController();
    final descController = TextEditingController();
    final imageController = TextEditingController();
    final distController = TextEditingController();
    
    // Default warranty status
    bool hasWarranty = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Product Name *'),
                    ),
                    TextField(
                      controller: modelController,
                      decoration: const InputDecoration(labelText: 'Model'),
                    ),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Description *'),
                      maxLines: 3,
                    ),
                    TextField(
                      controller: imageController,
                      decoration: const InputDecoration(labelText: 'Image URL'),
                    ),
                    TextField(
                      controller: distController,
                      decoration: const InputDecoration(labelText: 'Distributor Info'),
                    ),
                    TextField(
                      controller: stockController,
                      decoration: const InputDecoration(labelText: 'Initial Stock Quantity *'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Has Warranty?'),
                        Spacer(),
                        Switch(
                          value: hasWarranty,
                          activeColor: _dark,
                          onChanged: (val) {
                            setDialogState(() {
                              hasWarranty = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Note: Prices are determined by the Sales team.', style: TextStyle(fontSize: 12, color: _dark, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final stock = int.tryParse(stockController.text.trim());
                    final desc = descController.text.trim();
                    if (name.isEmpty || stock == null || desc.isEmpty) return;

                    Navigator.pop(context);
                    final newProduct = await ProductAdminService.createProduct({
                      'name': name,
                      'model': modelController.text.trim(),
                      'description': desc,
                      'image_url': imageController.text.trim(),
                      'distributor_info': distController.text.trim(),
                      'stock_quantity': stock,
                      'warranty_status': hasWarranty,
                      // 'category': null, // category can be null if DB allows
                    });

                    if (newProduct != null) {
                      _fetchProducts();
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to add product.'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),
        backgroundColor: _cream,
        foregroundColor: _dark,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        backgroundColor: _dark,
        child: const Icon(Icons.add, color: _offWhite),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('\$${product.price} - Stock: ${product.stockQuantity}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(product.isActive ? 'Active' : 'Inactive', style: TextStyle(color: product.isActive ? Colors.green : Colors.grey)),
                        Tooltip(
                          message: product.price <= 0.0 ? 'Price must be set by Sales Team to enable' : '',
                          child: Switch(
                            value: product.isActive,
                            activeColor: _dark,
                            onChanged: product.price <= 0.0 ? null : (val) => _toggleProductStatus(product, val),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
