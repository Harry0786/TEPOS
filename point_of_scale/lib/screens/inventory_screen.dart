import 'package:flutter/material.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: const Color(0xFF6B8E7F),
      ),
      body: const Center(
        child: Text(
          'Inventory Management Coming Soon!',
          style: TextStyle(fontSize: 18, color: Colors.black54),
        ),
      ),
    );
  }
}
