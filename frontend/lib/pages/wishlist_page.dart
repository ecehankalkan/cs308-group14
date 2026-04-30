import 'package:flutter/material.dart';

const _dark = Color(0xFF8D7B68);
const _cream = Color(0xFFF1DEC9);
const _offWhite = Color(0xFFFAF5EF);

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      appBar: AppBar(
        backgroundColor: _dark,
        foregroundColor: _offWhite,
        title: const Text('Wishlist'),
      ),
      body: Container(
        width: double.infinity,
        color: _cream,
        child: const Center(
          child: Text(
            'Wishlist page coming soon',
            style: TextStyle(
              color: _dark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
