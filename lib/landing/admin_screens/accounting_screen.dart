import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _allStudents = [];

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all students from the students collection
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();

      // Get all billing data
      final billingsSnapshot = await FirebaseFirestore.instance
          .collection('billings')
          .get();

      // Create a map of userUID to billing data for quick lookup
      final billingsMap = {};
      for (var doc in billingsSnapshot.docs) {
        billingsMap[doc.id] = doc.data();
      }

      // Combine student and billing data
      _allStudents = [];
      for (var doc in studentsSnapshot.docs) {
        final studentData = doc.data();
        final userUID = doc.id;

        if (billingsMap.containsKey(userUID)) {
          final billingData = billingsMap[userUID];

          _allStudents.add({
            'userUID': userUID,
            'username': studentData['username'] ?? 'Unknown',
            'email': studentData['email'] ?? '',
            'description': billingData['description'] ?? '',
            'summary': billingData['summary'] ?? '',
            'remainingBalance': billingData['remainingBalance'] ?? 0,
            'amount': billingData['amount'] ?? 0,
            'paymentDueDates': billingData['paymentDueDates'] ?? [],
          });
        }
      }

      _filterStudents();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterStudents() {
    if (_searchQuery.isEmpty) {
      _filteredStudents = List.from(_allStudents);
    } else {
      _filteredStudents = _allStudents.where((student) {
        final username = student['username'].toString().toLowerCase();
        final email = student['email'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return username.contains(query) || email.contains(query);
      }).toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Billings'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudentData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _filterStudents();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _filterStudents();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Total Students: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('${_filteredStudents.length}'),
                    const Spacer(),
                    const Text(
                      'Total Outstanding: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₱${_filteredStudents.fold(0.0, (sum, student) => sum + ((student['remainingBalance'] ?? 0) as num).toDouble()).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Student list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStudents.isEmpty
                ? const Center(child: Text('No students found'))
                : ListView.builder(
                    itemCount: _filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = _filteredStudents[index];
                      final remainingBalance = student['remainingBalance'] ?? 0;
                      final nextPayment =
                          student['paymentDueDates'] != null &&
                              student['paymentDueDates'].isNotEmpty
                          ? student['paymentDueDates'][0]
                          : null;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          title: Text(
                            student['username'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student['email'] ?? ''),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text('Balance: '),
                                  Text(
                                    '₱${remainingBalance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: remainingBalance > 0
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF4CAF50),
                            child: Text(
                              student['username']
                                      ?.substring(0, 1)
                                      .toUpperCase() ??
                                  '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          trailing: nextPayment != null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Next Payment',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      nextPayment['dueDate'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow(
                                    'Description',
                                    student['description'] ?? '',
                                  ),
                                  _buildInfoRow(
                                    'Summary',
                                    student['summary'] ?? '',
                                  ),
                                  _buildInfoRow(
                                    'Total Amount',
                                    '₱${(student['amount'] ?? 0).toStringAsFixed(2)}',
                                  ),
                                  _buildInfoRow(
                                    'Remaining',
                                    '₱${remainingBalance.toStringAsFixed(2)}',
                                  ),

                                  const SizedBox(height: 16),
                                  const Text(
                                    'Payment Schedule',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Payment schedule table
                                  if (student['paymentDueDates'] != null &&
                                      student['paymentDueDates'].isNotEmpty)
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
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(8),
                                                    topRight: Radius.circular(
                                                      8,
                                                    ),
                                                  ),
                                            ),
                                            child: Row(
                                              children: const [
                                                Expanded(
                                                  child: Text(
                                                    'Due Date',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    'Amount',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    'Status',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Table rows
                                          ...List.generate(
                                            student['paymentDueDates'].length,
                                            (i) {
                                              final payment =
                                                  student['paymentDueDates'][i];
                                              final dueDate =
                                                  payment['dueDate'] ?? '';
                                              final amount =
                                                  payment['amount'] ?? 0;
                                              final isPaid =
                                                  payment['paid'] ?? false;

                                              // Check if payment is due
                                              bool isOverdue = false;
                                              try {
                                                final dueDateObj = DateFormat(
                                                  'yyyy-MM-dd',
                                                ).parse(dueDate);
                                                isOverdue =
                                                    !isPaid &&
                                                    dueDateObj.isBefore(
                                                      DateTime.now(),
                                                    );
                                              } catch (e) {
                                                // Handle date parsing error
                                              }

                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 16,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    top: BorderSide(
                                                      color:
                                                          Colors.grey.shade300,
                                                    ),
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
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: isPaid
                                                              ? Colors
                                                                    .green
                                                                    .shade100
                                                              : isOverdue
                                                              ? Colors
                                                                    .red
                                                                    .shade100
                                                              : Colors
                                                                    .orange
                                                                    .shade100,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Text(
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

                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.edit),
                                        label: const Text('Edit'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          // TODO: Implement edit functionality
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.payment),
                                        label: const Text('Record Payment'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF4CAF50,
                                          ),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          // TODO: Implement payment recording
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add),
        onPressed: () {
          // TODO: Implement add new billing functionality
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
