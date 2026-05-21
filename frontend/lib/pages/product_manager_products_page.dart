import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/product_service.dart';

class ProductManagerProductsPage extends StatefulWidget {
  const ProductManagerProductsPage({super.key});

  @override
  State<ProductManagerProductsPage> createState() => _ProductManagerProductsPageState();
}

class _ProductManagerProductsPageState extends State<ProductManagerProductsPage> {
  final ProductService _productService = ProductService();
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final list = await _productService.fetchAllProducts();
    if (!mounted) return;
    setState(() {
      _products = list;
      _loading = false;
    });
  }

  Future<void> _editStock(Product product) async {
    final controller = TextEditingController(text: product.stockQuantity.toString());
    final formKey = GlobalKey<FormState>();

    final newStock = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Stock: ${product.name}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock Quantity',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Please enter a number';
                final parsed = int.tryParse(val);
                if (parsed == null || parsed < 0) return 'Please enter a valid positive integer';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(int.parse(controller.text));
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newStock != null) {
      setState(() => _loading = true);
      final updated = await _productService.updateProductStock(product.id, newStock);
      if (!mounted) return;
      
      if (updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock updated successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadProducts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update stock.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Product Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Catalog & Inventory',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'View and update the stock levels of books. Price and discount configuration fields are restricted to Sales Managers.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                      ? const Center(child: Text('No products found.'))
                      : Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListView.separated(
                            itemCount: _products.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                title: Text(
                                  product.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Category: ${product.category.name}'),
                                    const SizedBox(height: 2),
                                    Text(
                                      product.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: product.stockQuantity > 0
                                            ? Colors.green.shade50
                                            : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Stock: ${product.stockQuantity}',
                                        style: TextStyle(
                                          color: product.stockQuantity > 0
                                              ? Colors.green.shade800
                                              : Colors.red.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Edit Stock'),
                                      onPressed: () => _editStock(product),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
