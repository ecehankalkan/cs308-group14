import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Commerce Store'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                final user = snapshot.data;
                return PopupMenuButton(
                  itemBuilder: (context) {
                    if (user != null) {
                      return [
                        PopupMenuItem(
                          enabled: false,
                          child: Text(
                            'Hi, ${user.displayName ?? 'User'}!',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                        PopupMenuItem(
                          child: const Text('Logout', style: TextStyle(color: Colors.red)),
                          onTap: () async {
                            await AuthService().signOut();
                          },
                        ),
                      ];
                    } else {
                      return [
                        PopupMenuItem(
                          child: const Text('Login'),
                          onTap: () => Navigator.pushNamed(context, '/login'),
                        ),
                        PopupMenuItem(
                          child: const Text('Sign Up'),
                          onTap: () => Navigator.pushNamed(context, '/signup'),
                        ),
                      ];
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Icon(Icons.account_circle, size: 32),
                  ),
                );
              }
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to Our Store',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 24),
            const Text('Browse and shop our products'),
          ],
        ),
      ),
    );
  }
}
