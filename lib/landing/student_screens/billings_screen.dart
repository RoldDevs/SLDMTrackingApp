import 'package:flutter/material.dart';

class BillingsScreen extends StatelessWidget {
  const BillingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billings'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Billings Screen'),
      ),
    );
  }
}