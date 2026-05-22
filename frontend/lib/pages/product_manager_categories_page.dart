import 'package:flutter/material.dart';
import '../services/product_admin_service.dart';

class ProductManagerCategoriesPage extends StatefulWidget {
  const ProductManagerCategoriesPage({super.key});

  @override
  State<ProductManagerCategoriesPage> createState() => _ProductManagerCategoriesPageState();
}

class _ProductManagerCategoriesPageState extends State<ProductManagerCategoriesPage> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _loading = true);
    final categories = await ProductAdminService.fetchCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        _loading = false;
      });
    }
  }

  Future<void> _toggleCategoryStatus(Map<String, dynamic> category, bool isActive) async {
    // Optimistic UI update
    setState(() {
      category['is_active'] = isActive;
    });

    final success = await ProductAdminService.updateCategoryStatus(category['id'] as int, isActive);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "\${category["name"]}" is now \${isActive ? "Visible" : "Hidden"}')),
      );
    } else if (mounted) {
      // Revert on failure
      setState(() {
        category['is_active'] = !isActive;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update category status.')),
      );
    }
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    // Default active status
    bool isActive = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Category Name *'),
                    ),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Visible?'),
                        Switch(
                          value: isActive,
                          onChanged: (val) {
                            setDialogState(() {
                              isActive = val;
                            });
                          },
                        ),
                      ],
                    ),
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
                    final desc = descController.text.trim();
                    if (name.isEmpty) return;

                    Navigator.pop(dialogContext);
                    final newCategory = await ProductAdminService.createCategory({
                      'name': name,
                      'description': desc,
                      'is_active': isActive,
                    });

                    if (newCategory != null) {
                      _fetchCategories(); // Refresh the list
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added category "\${newCategory["name"]}"')),
                        );
                      }
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to add category')),
                      );
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(child: Text('No categories found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isActive = category['is_active'] as bool? ?? true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(category['name'] as String),
                        subtitle: Text(category['description'] as String? ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(isActive ? 'Visible' : 'Hidden'),
                            Switch(
                              value: isActive,
                              onChanged: (val) => _toggleCategoryStatus(category, val),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        tooltip: 'Add Category',
        child: const Icon(Icons.add),
      ),
    );
  }
}
