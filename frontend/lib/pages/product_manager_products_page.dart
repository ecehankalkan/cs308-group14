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
    final priceController = TextEditingController();
    final stockController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: stockController,
                  decoration: const InputDecoration(labelText: 'Initial Stock Quantity'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Text('More fields like category, distributor, and warranty can be added later.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                final price = double.tryParse(priceController.text.trim());
                final stock = int.tryParse(stockController.text.trim());
                if (name.isEmpty || price == null || stock == null) return;

                Navigator.pop(context);
                final newProduct = await ProductAdminService.createProduct({
                  'name': name,
                  'price': price,
                  'description': 'Description for $name',
                  'stock_quantity': stock,
                  'warranty_status': true,
                  'distributor_info': 'Default Dist',
                  // 'category': null, // category can be null if DB allows
                });

                if (newProduct != null) {
                  _fetchProducts();
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to add product (Make sure there is a Category or it allows null)'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
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
                        Switch(
                          value: product.isActive,
                          activeColor: _dark,
                          onChanged: (val) => _toggleProductStatus(product, val),
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
