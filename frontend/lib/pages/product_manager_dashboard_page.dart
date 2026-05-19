import 'package:flutter/material.dart';

class ProductManagerDashboardPage extends StatelessWidget {
  const ProductManagerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Product Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome, Product Manager',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: const [
                  _DashboardButton(
                    icon: Icons.inventory_2,
                    label: 'Products',
                  ),
                  _DashboardButton(
                    icon: Icons.category,
                    label: 'Categories',
                  ),
                  _DashboardButton(
                    icon: Icons.receipt_long,
                    label: 'Past Orders',
                  ),
                  _DashboardButton(
                    icon: Icons.local_shipping,
                    label: 'Delivery Status',
                  ),
                  _DashboardButton(
                    icon: Icons.comment,
                    label: 'Comments',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DashboardButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 140,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
