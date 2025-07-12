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
  Map<String, List<int>> _pendingApprovals =
      {}; // Track pending approval requests

  @override
  void initState() {
    super.initState();
    _loadBillings();
    _loadPendingApprovals();
  }

  // Load any pending approval requests
  Future<void> _loadPendingApprovals() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection('forApproval')
          .where('userUID', isEqualTo: user.uid)
          .get();

      Map<String, List<int>> pendingApprovals = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final billingId = data['billingId'] as String;
        final paymentIndex = data['paymentIndex'] as int;

        if (!pendingApprovals.containsKey(billingId)) {
          pendingApprovals[billingId] = [];
        }
        pendingApprovals[billingId]!.add(paymentIndex);
      }

      setState(() {
        _pendingApprovals = pendingApprovals;
      });
    } catch (e) {
      print('Error loading pending approvals: $e');
    }
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

  // Request status change for a payment
  Future<void> _requestStatusChange(
    String billingId,
    int paymentIndex,
    bool currentStatus,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check if this payment is already paid and approved
      final billing = _billings.firstWhere((b) => b['id'] == billingId);
      final payment = billing['paymentDueDates'][paymentIndex];

      // If payment is already paid and approved, don't allow changes
      if (payment['paid'] == true && payment['approved'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Approved payments cannot be changed')),
        );
        return;
      }

      // Check if there's already a pending request
      bool hasPendingRequest =
          _pendingApprovals.containsKey(billingId) &&
          _pendingApprovals[billingId]!.contains(paymentIndex);

      if (hasPendingRequest) {
        // Delete the existing request
        final querySnapshot = await _firestore
            .collection('forApproval')
            .where('userUID', isEqualTo: user.uid)
            .where('billingId', isEqualTo: billingId)
            .where('paymentIndex', isEqualTo: paymentIndex)
            .get();

        for (var doc in querySnapshot.docs) {
          await doc.reference.delete();
        }

        // Update local state
        setState(() {
          _pendingApprovals[billingId]!.remove(paymentIndex);
          if (_pendingApprovals[billingId]!.isEmpty) {
            _pendingApprovals.remove(billingId);
          }
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request cancelled')));
      } else {
        // Show the status selection dialog instead of trying to create a request directly
        await _showStatusSelectionDialog(billingId, paymentIndex, currentStatus);
      }
    } catch (e) {
      print('Error requesting status change: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Show dialog to select payment status
  Future<void> _showStatusSelectionDialog(
    String billingId,
    int paymentIndex,
    bool currentStatus,
  ) async {
    final payment = _billings.firstWhere(
      (b) => b['id'] == billingId,
    )['paymentDueDates'][paymentIndex];
    final dueDate = payment['dueDate'] ?? '';
    final amount = payment['amount'] ?? 0.0;

    // Default to the opposite of current status
    bool newStatus = !currentStatus;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Payment Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Due Date: $dueDate'),
            Text('Amount: ₱${amount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text('Select new status:'),
            const SizedBox(height: 8),
            RadioListTile<bool>(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  const Text('Paid'),
                ],
              ),
              value: true,
              groupValue: newStatus,
              onChanged: (value) {
                setState(() {
                  newStatus = value!;
                });
              },
            ),
            RadioListTile<bool>(
              title: Row(
                children: [
                  Icon(Icons.cancel, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  const Text('Overdue'), // Changed from 'Unpaid' to 'Overdue'
                ],
              ),
              value: false,
              groupValue: newStatus,
              onChanged: (value) {
                setState(() {
                  newStatus = value!;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitStatusChange(
                billingId,
                paymentIndex,
                currentStatus,
                newStatus,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit for Approval'),
          ),
        ],
      ),
    );
  }

  // Submit status change request
  Future<void> _submitStatusChange(
    String billingId,
    int paymentIndex,
    bool currentStatus,
    bool newStatus,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check if this payment is already paid and approved
      final billing = _billings.firstWhere((b) => b['id'] == billingId);
      final payment = billing['paymentDueDates'][paymentIndex];
      final dueDate = payment['dueDate'] ?? '';
      final amount = payment['amount'] ?? 0.0;

      // If payment is already paid and approved, don't allow changes
      if (payment['paid'] == true && payment['approved'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Approved payments cannot be changed')),
        );
        return;
      }

      // Check if there's already a pending request
      bool hasPendingRequest =
          _pendingApprovals.containsKey(billingId) &&
          _pendingApprovals[billingId]!.contains(paymentIndex);

      if (hasPendingRequest) {
        // Delete the existing request
        final querySnapshot = await _firestore
            .collection('forApproval')
            .where('userUID', isEqualTo: user.uid)
            .where('billingId', isEqualTo: billingId)
            .where('paymentIndex', isEqualTo: paymentIndex)
            .get();

        for (var doc in querySnapshot.docs) {
          await doc.reference.delete();
        }

        // Update local state
        setState(() {
          _pendingApprovals[billingId]!.remove(paymentIndex);
          if (_pendingApprovals[billingId]!.isEmpty) {
            _pendingApprovals.remove(billingId);
          }
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request cancelled')));
      } else {
        // Create a new request
        await _firestore.collection('forApproval').add({
          'userUID': user.uid,
          'username': user.displayName ?? '',
          'studentName': user.displayName ?? '',
          'studentEmail': user.email ?? '',
          'billingId': billingId,
          'paymentIndex': paymentIndex,
          'currentStatus': currentStatus,
          'newPaidStatus': newStatus,
          'dueDate': dueDate,
          'amount': amount,
          'timestamp': FieldValue.serverTimestamp(),
          'approved': false,
        });

        // Update local state
        setState(() {
          if (!_pendingApprovals.containsKey(billingId)) {
            _pendingApprovals[billingId] = [];
          }
          _pendingApprovals[billingId]!.add(paymentIndex);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted for approval')),
        );
      }
    } catch (e) {
      print('Error requesting status change: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
            onPressed: () {
              _loadBillings();
              _loadPendingApprovals();
            },
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
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
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
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              'Amount',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              'Status',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Table rows
                                    ...List.generate(billing['paymentDueDates'].length, (
                                      i,
                                    ) {
                                      final payment =
                                          billing['paymentDueDates'][i];
                                      final dueDate = payment['dueDate'] ?? '';
                                      final amount = payment['amount'] ?? 0;
                                      final isPaid = payment['paid'] ?? false;
                                      final isApproved =
                                          payment['approved'] ?? false;
                                      final paidDate = payment['paidDate'];

                                      // Check if there's a pending approval for this payment
                                      final hasPendingRequest =
                                          _pendingApprovals.containsKey(
                                            billing['id'],
                                          ) &&
                                          _pendingApprovals[billing['id']]!
                                              .contains(i);

                                      // Check if payment is due
                                      bool isOverdue = false;
                                      try {
                                        final dueDateObj = DateFormat(
                                          'yyyy-MM-dd',
                                        ).parse(dueDate);
                                        isOverdue =
                                            !isPaid &&
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
                                            top: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          color: i % 2 == 0
                                              ? Colors.white
                                              : Colors.grey.shade50,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(child: Text(dueDate)),
                                            Expanded(
                                              child: Text(
                                                '₱${amount.toStringAsFixed(2)}',
                                              ),
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () {
                                                  // Only allow changes if not approved
                                                  if (!isApproved) {
                                                    _showStatusSelectionDialog(
                                                      billing['id'],
                                                      i,
                                                      isPaid,
                                                    );
                                                  } else if (isPaid &&
                                                      isApproved) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Approved payments cannot be changed',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isPaid
                                                        ? Colors.green.shade100
                                                        : isOverdue
                                                        ? Colors.red.shade100
                                                        : Colors
                                                              .orange
                                                              .shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: hasPendingRequest
                                                        ? Border.all(
                                                            color: Colors.blue,
                                                            width: 2,
                                                          )
                                                        : null,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        isPaid
                                                            ? 'Paid'
                                                            : isOverdue
                                                            ? 'Overdue'
                                                            : 'Pending',
                                                        style: TextStyle(
                                                          color: isPaid
                                                              ? Colors
                                                                    .green
                                                                    .shade800
                                                              : isOverdue
                                                              ? Colors
                                                                    .red
                                                                    .shade800
                                                              : Colors
                                                                    .orange
                                                                    .shade800,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                      if (isPaid &&
                                                          paidDate != null)
                                                        Text(
                                                          'on $paidDate',
                                                          style: TextStyle(
                                                            color: Colors
                                                                .green
                                                                .shade800,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      if (!isApproved)
                                                        Text(
                                                          hasPendingRequest
                                                              ? 'Awaiting approval'
                                                              : 'Tap to change',
                                                          style: TextStyle(
                                                            color:
                                                                hasPendingRequest
                                                                ? Colors
                                                                      .blue
                                                                      .shade800
                                                                : Colors
                                                                      .grey
                                                                      .shade700,
                                                            fontSize: 10,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
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

// Helper method to get username from Firestore
Future<String> _getUserName(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('students')
        .doc(uid)
        .get();

    if (doc.exists && doc.data()?['username'] != null) {
      return doc.data()?['username'];
    }
    return '';
  } catch (e) {
    print('Error fetching username: $e');
    return '';
  }
}
