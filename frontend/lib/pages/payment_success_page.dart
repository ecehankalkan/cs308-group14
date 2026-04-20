import 'package:flutter/material.dart';

const _dark = Color(0xFF8D7B68);
const _medium = Color(0xFFA4907C);
const _offWhite = Color(0xFFFAF5EF);

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.green.shade400,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    Icons.check,
                    size: 70,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Payment Successful!',
                  style: TextStyle(
                    color: _dark,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your order has been placed',
                  style: TextStyle(
                    color: _medium,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: _dark, size: 32),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              splashRadius: 24,
            ),
          ),
        ],
      ),
    );
  }
}
