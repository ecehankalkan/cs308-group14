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
  List<Map<String, dynamic>> _categories = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final products = await ProductAdminService.fetchAllProducts();
    final categories = await ProductAdminService.fetchCategories();
    if (mounted) {
      setState(() {
        _products = products;
        _categories = categories;
        _loading = false;
      });
    }
  }

  Future<void> _fetchProducts() async {
    setState(() => _loading = true);
    final products = await ProductAdminService.fetchAllProducts();
    if (mounted) {
      setState(() {
        _products = products;
        _loading = false;
      });
    }
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

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Permanently delete "${product.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await ProductAdminService.deleteProduct(product.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _products.removeWhere((p) => p.id == product.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} deleted.'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete product.'), backgroundColor: Colors.red),
      );
    }
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
      final updated = await ProductAdminService.updateProductStock(product.id, newStock);
      if (!mounted) return;

      if (updated != null) {
        setState(() {
          final index = _products.indexWhere((p) => p.id == product.id);
          if (index != -1) {
            _products[index] = updated;
          }
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update stock.'),
            backgroundColor: Colors.red,
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
    int? selectedCategoryId;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
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
                    if (_categories.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'Category *'),
                        value: selectedCategoryId,
                        items: _categories.map((cat) {
                          return DropdownMenuItem<int>(
                            value: cat['id'] as int,
                            child: Text(cat['name'] as String),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedCategoryId = val;
                          });
                        },
                      ),
                    ],
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final stock = int.tryParse(stockController.text.trim());
                    final desc = descController.text.trim();
                    if (name.isEmpty || stock == null || desc.isEmpty) return;

                    Navigator.pop(dialogContext);
                    final newProduct = await ProductAdminService.createProduct({
                      'name': name,
                      'model': modelController.text.trim(),
                      'description': desc,
                      'image_url': imageController.text.trim(),
                      'distributor_info': distController.text.trim(),
                      'stock_quantity': stock,
                      'warranty_status': hasWarranty,
                      'category': selectedCategoryId,
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Product Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        backgroundColor: _dark,
        child: const Icon(Icons.add, color: _offWhite),
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
                                    Text('Category: ${_categories.firstWhere((c) => c['id'] == product.categoryId, orElse: () => {'name': 'Unknown'})['name']}'),
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
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Delete product',
                                      onPressed: () => _deleteProduct(product),
                                    ),
                                    const SizedBox(width: 16),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          product.isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: product.isActive ? Colors.green : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
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
