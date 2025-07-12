import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class BillingsScreen extends StatefulWidget {
  const BillingsScreen({super.key});

  @override
  State<BillingsScreen> createState() => _BillingsScreenState();
}

class _BillingsScreenState extends State<BillingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _billings = [];

  @override
  void initState() {
    super.initState();
    _loadBillings();
  }

  Future<void> _loadBillings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final snapshot = await _firestore
          .collection('billings')
          .where('userUID', isEqualTo: user.uid)
          .get();

      final billings = snapshot.docs.map((doc) {
        final data = doc.data();
        
        // Calculate remaining balance
        double totalAmount = data['amount'] ?? 0.0;
        double remainingBalance = totalAmount;
        
        // Calculate paid amount from payment schedule
        if (data['paymentDueDates'] != null) {
          List<dynamic> paymentSchedule = data['paymentDueDates'];
          for (var payment in paymentSchedule) {
            if (payment['paid'] == true) {
              remainingBalance -= payment['amount'] ?? 0.0;
            }
          }
        }
        
        // Ensure we don't have negative balance
        remainingBalance = remainingBalance < 0 ? 0 : remainingBalance;
        
        return {
          'id': doc.id,
          ...data,
          'calculatedRemainingBalance': remainingBalance,
        };
      }).toList();

      setState(() {
        _billings = billings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading billings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Billings'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBillings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _billings.isEmpty
              ? const Center(child: Text('No billing records found'))
              : ListView.builder(
                  itemCount: _billings.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final billing = _billings[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        title: Text(
                          billing['description'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text('Balance: '),
                                Text(
                                  '₱${billing['calculatedRemainingBalance'].toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: billing['calculatedRemainingBalance'] > 0
                                        ? Colors.red
                                        : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow('Summary', billing['summary'] ?? ''),
                                _buildInfoRow(
                                  'Total Amount',
                                  '₱${(billing['amount'] ?? 0).toStringAsFixed(2)}',
                                ),
                                _buildInfoRow(
                                  'Remaining',
                                  '₱${billing['calculatedRemainingBalance'].toStringAsFixed(2)}',
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Payment Schedule',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                if (billing['paymentDueDates'] != null &&
                                    billing['paymentDueDates'].isNotEmpty)
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        // Table header
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(8),
                                              topRight: Radius.circular(8),
                                            ),
                                          ),
                                          child: Row(
                                            children: const [
                                              Expanded(
                                                child: Text(
                                                  'Due Date',
                                                  style: TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  'Amount',
                                                  style: TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  'Status',
                                                  style: TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Table rows
                                        ...List.generate(
                                          billing['paymentDueDates'].length,
                                          (i) {
                                            final payment = billing['paymentDueDates'][i];
                                            final dueDate = payment['dueDate'] ?? '';
                                            final amount = payment['amount'] ?? 0;
                                            final isPaid = payment['paid'] ?? false;
                                            final paidDate = payment['paidDate'];

                                            // Check if payment is due
                                            bool isOverdue = false;
                                            try {
                                              final dueDateObj =
                                                  DateFormat('yyyy-MM-dd').parse(dueDate);
                                              isOverdue = !isPaid &&
                                                  dueDateObj.isBefore(DateTime.now());
                                            } catch (e) {
                                              // Handle date parsing error
                                            }

                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 12,
                                                horizontal: 16,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  top: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                color: i % 2 == 0
                                                    ? Colors.white
                                                    : Colors.grey.shade50,
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(dueDate),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      '₱${amount.toStringAsFixed(2)}',
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: isPaid
                                                            ? Colors.green.shade100
                                                            : isOverdue
                                                                ? Colors.red.shade100
                                                                : Colors.orange.shade100,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        children: [
                                                          Text(
                                                            isPaid
                                                                ? 'Paid'
                                                                : isOverdue
                                                                    ? 'Overdue'
                                                                    : 'Pending',
                                                            style: TextStyle(
                                                              color: isPaid
                                                                  ? Colors.green.shade800
                                                                  : isOverdue
                                                                      ? Colors.red.shade800
                                                                      : Colors.orange.shade800,
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                            textAlign: TextAlign.center,
                                                          ),
                                                          if (isPaid && paidDate != null)
                                                            Text(
                                                              'on $paidDate',
                                                              style: TextStyle(
                                                                color: Colors.green.shade800,
                                                                fontSize: 10,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  const Text('No payment schedule available'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}