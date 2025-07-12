import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

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
      print('DEBUG: Starting to load student data');

      // Get all students first
      print('DEBUG: Fetching all students...');
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();

      print('DEBUG: Found ${studentsSnapshot.docs.length} students');

      if (studentsSnapshot.docs.isEmpty) {
        print('DEBUG: No students found in database');
        setState(() {
          _allStudents = [];
          _filteredStudents = [];
          _isLoading = false;
        });
        return;
      }

      // Get all billing records
      print('DEBUG: Fetching billing records...');
      final billingsSnapshot = await FirebaseFirestore.instance
          .collection('billings')
          .get();

      print('DEBUG: Found ${billingsSnapshot.docs.length} billing records');

      // Create a map of billing data by userUID
      final Map<String, Map<String, dynamic>> billingsByUser = {};

      // Process billing data
      for (var doc in billingsSnapshot.docs) {
        final data = doc.data();
        final userUID = data['userUID'] as String?;

        if (userUID != null) {
          billingsByUser[userUID] = {...data, 'id': doc.id};
        }
      }

      // Process all students, with or without billing data
      final List<Map<String, dynamic>> combinedData = [];

      for (var doc in studentsSnapshot.docs) {
        final studentData = doc.data();
        final userUID = studentData['userUID'] as String? ?? doc.id;

        // Create base student record
        Map<String, dynamic> studentRecord = {
          ...studentData,
          'id': doc.id,
          'userUID': userUID, // Ensure userUID is always set
          'calculatedRemainingBalance': 0.0,
        };

        // Add billing data if available
        if (billingsByUser.containsKey(userUID)) {
          final billingData = billingsByUser[userUID]!;

          // Calculate remaining balance
          double totalAmount = (billingData['amount'] ?? 0).toDouble();
          double remainingBalance = totalAmount;

          // Calculate paid amount from payment schedule
          if (billingData['paymentDueDates'] != null) {
            List<dynamic> paymentSchedule = billingData['paymentDueDates'];
            for (var payment in paymentSchedule) {
              if (payment['paid'] == true) {
                remainingBalance -= (payment['amount'] ?? 0).toDouble();
              }
            }
          }

          // Ensure we don't have negative balance
          remainingBalance = remainingBalance < 0 ? 0 : remainingBalance;

          // Merge billing data with student data
          studentRecord = {
            ...studentRecord,
            ...billingData,
            'calculatedRemainingBalance': remainingBalance,
          };
        } else {
          // No billing data for this student
          print('DEBUG: No billing data for student $userUID');
          studentRecord['paymentDueDates'] = [];
          studentRecord['amount'] = 0.0;
          studentRecord['remainingBalance'] = 0.0;
          studentRecord['description'] = 'No billing information';
          studentRecord['summary'] = 'No billing information';
        }

        combinedData.add(studentRecord);
      }

      print('DEBUG: Final combined records count: ${combinedData.length}');

      setState(() {
        _allStudents = combinedData;
        _filteredStudents = combinedData;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('ERROR loading data: $e');
      print('Stack trace: $stackTrace');

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(label: 'RETRY', onPressed: _loadStudentData),
        ),
      );
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
                      '₱${_filteredStudents.fold(0.0, (sum, student) => sum + ((student['calculatedRemainingBalance'] ?? 0) as num).toDouble()).toStringAsFixed(2)}',
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
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: ExpansionTile(
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.start,
                            expandedAlignment: Alignment.centerLeft,
                            childrenPadding: EdgeInsets.zero,
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(
                              student['username'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student['email'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text('Balance: '),
                                    Text(
                                      '₱${student['calculatedRemainingBalance'].toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color:
                                            student['calculatedRemainingBalance'] >
                                                0
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
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                nextPayment != null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
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
                                    : const SizedBox(),
                              ],
                            ),
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
                                      '₱${student['calculatedRemainingBalance'].toStringAsFixed(2)}',
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.file_download,
                                            color: Colors.blue,
                                          ),
                                          tooltip: 'Export to Excel',
                                          onPressed: () =>
                                              _exportToExcel(student),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.picture_as_pdf,
                                            color: Colors.red,
                                          ),
                                          tooltip: 'Export to PDF',
                                          onPressed: () =>
                                              _exportToPDF(student),
                                        ),
                                      ],
                                    ),
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            // Table header
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 16,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      topLeft: Radius.circular(
                                                        8,
                                                      ),
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
                                            ...List.generate(student['paymentDueDates'].length, (
                                              i,
                                            ) {
                                              final payment =
                                                  student['paymentDueDates'][i];
                                              // Store both the CellValue version and String/numeric versions
                                              final dueDateCell =
                                                  (payment['dueDate'] ?? '')
                                                      as CellValue;
                                              final dueDate =
                                                  payment['dueDate'] ?? '';

                                              final amountCell =
                                                  (payment['amount'] ?? 0)
                                                      as CellValue;
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
                                                        '₱${(amount is int ? amount.toDouble() : amount).toStringAsFixed(2)}',
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
                                            }),
                                          ],
                                        ),
                                      )
                                    else
                                      const Text(
                                        'No payment schedule available',
                                      ),

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
                                            _showEditBillingDialog(student);
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.delete),
                                          label: const Text('Delete'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () {
                                            _showDeleteConfirmationDialog(
                                              student,
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.payment),
                                          label: const Text('Record'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF4CAF50,
                                            ),
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () {
                                            _showRecordPaymentDialog(student);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
          // Show dialog to select a student first
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Select Student'),
              content: SizedBox(
                width: double.maxFinite,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _allStudents.isEmpty
                    ? const Center(child: Text('No students found'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _allStudents.length,
                        itemBuilder: (context, index) {
                          final student = _allStudents[index];
                          return ListTile(
                            title: Text(student['username'] ?? 'Unknown'),
                            subtitle: Text(student['email'] ?? ''),
                            onTap: () {
                              Navigator.pop(context);
                              _showAddBillingDialog(
                                studentId: student['userUID'],
                                studentName: student['username'],
                                studentEmail: student['email'],
                              );
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
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

  Future<String?> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      return DateFormat('yyyy-MM-dd').format(picked);
    }
    return null;
  }

  Future<double?> _showAmountInputDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<double?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Amount'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (₱)',
            hintText: 'e.g., 5000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context, amount);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel(Map<String, dynamic> student) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Billing Details'];

      void setCell(int col, int row, dynamic value) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );

        // Determine correct CellValue subclass
        if (value == null) {
          cell.value = null;
        } else if (value is int) {
          cell.value = IntCellValue(value);
        } else if (value is double) {
          cell.value = DoubleCellValue(value);
        } else if (value is bool) {
          cell.value = BoolCellValue(value);
        } else {
          cell.value = TextCellValue(value.toString());
        }
      }

      // Header Row
      final headers = [
        'Student Name',
        'Email',
        'Description',
        'Summary',
        'Total Amount',
        'Remaining Balance',
      ];

      for (int i = 0; i < headers.length; i++) {
        setCell(i, 0, headers[i]);
      }

      // Student Info
      setCell(0, 1, student['username'] ?? 'Unknown');
      setCell(1, 1, student['email'] ?? '');
      setCell(2, 1, student['description'] ?? '');
      setCell(3, 1, student['summary'] ?? '');
      setCell(4, 1, student['amount'] ?? 0);
      setCell(5, 1, student['calculatedRemainingBalance'] ?? 0);

      // Payment Schedule Header
      setCell(0, 3, 'Payment Schedule');
      setCell(0, 4, 'Due Date');
      setCell(1, 4, 'Amount');
      setCell(2, 4, 'Status');
      setCell(3, 4, 'Paid Date');

      // Payment Rows
      if (student['paymentDueDates'] != null) {
        int rowIndex = 5;
        for (var payment in student['paymentDueDates']) {
          setCell(0, rowIndex, payment['dueDate'] ?? '');
          setCell(1, rowIndex, payment['amount'] ?? 0);
          setCell(2, rowIndex, payment['paid'] == true ? 'Paid' : 'Pending');
          setCell(3, rowIndex, payment['paidDate'] ?? '');
          rowIndex++;
        }
      }

      // Save the Excel file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          '${student['username']}_billing_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      await OpenFile.open(filePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel file exported to $filePath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting to Excel: $e')));
    }
  }

  Future<void> _exportToPDF(Map<String, dynamic> student) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, child: pw.Text('Student Billing Report')),
              pw.SizedBox(height: 20),

              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(
                          'Student Name',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(student['username'] ?? 'Unknown'),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(
                          'Email',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(student['email'] ?? ''),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(student['description'] ?? ''),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(
                          'Summary',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(student['summary'] ?? ''),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(
                          'Total Amount',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(
                          '₱${(student['amount'] ?? 0).toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(
                          'Remaining Balance',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(
                          '₱${student['calculatedRemainingBalance'].toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Header(level: 1, child: pw.Text('Payment Schedule')),
              pw.SizedBox(height: 10),

              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(
                          'Due Date',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(
                          'Amount',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text(
                          'Status',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  // Payment rows
                  if (student['paymentDueDates'] != null)
                    ...List.generate(student['paymentDueDates'].length, (
                      index,
                    ) {
                      final payment = student['paymentDueDates'][index];
                      final isPaid = payment['paid'] ?? false;
                      final status = isPaid ? 'Paid' : 'Pending';

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8.0),
                            child: pw.Text(payment['dueDate'] ?? ''),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8.0),
                            child: pw.Text(
                              '₱${(payment['amount'] ?? 0).toStringAsFixed(2)}',
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8.0),
                            child: pw.Text(status),
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ];
          },
        ),
      );

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/${student['username'] ?? 'student'}_billing.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      // Open file
      await OpenFile.open(path);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF file saved to $path')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting to PDF: $e')));
    }
  }

  // Add this method to the _AccountingScreenState class
  void _showAddBillingDialog({
    required String studentId,
    required String studentName,
    required String studentEmail,
  }) {
    final descriptionController = TextEditingController();
    final summaryController = TextEditingController();
    final amountController = TextEditingController();
    final dueDateController = TextEditingController();
    final paymentAmountController = TextEditingController();

    List<Map<String, dynamic>> paymentSchedule = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add Billing for $studentName'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g., Tuition Fee for 2023-2024',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: summaryController,
                  decoration: const InputDecoration(
                    labelText: 'Summary',
                    hintText: 'Brief summary of the billing',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Total Amount (₱)',
                    hintText: 'e.g., 10000',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Payment Schedule',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Display added payment schedule items
                if (paymentSchedule.isNotEmpty) ...[
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
                              SizedBox(width: 40),
                            ],
                          ),
                        ),

                        // Payment schedule items
                        ...List.generate(
                          paymentSchedule.length,
                          (i) => Container(
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
                                  child: Text(paymentSchedule[i]['dueDate']),
                                ),
                                Expanded(
                                  child: Text(
                                    '₱${paymentSchedule[i]['amount'].toStringAsFixed(2)}',
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        paymentSchedule.removeAt(i);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else
                  const Text('No payment schedule added yet'),

                const SizedBox(height: 16),

                // Add payment schedule form
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dueDateController,
                        decoration: const InputDecoration(
                          labelText: 'Due Date',
                          hintText: 'YYYY-MM-DD',
                        ),
                        onTap: () async {
                          // Show date picker
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 2),
                            ),
                          );
                          if (date != null) {
                            dueDateController.text = DateFormat(
                              'yyyy-MM-dd',
                            ).format(date);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: paymentAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount (₱)',
                          hintText: 'e.g., 5000',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add to Schedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // Validate inputs
                    if (dueDateController.text.isEmpty ||
                        paymentAmountController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }

                    // Parse amount
                    double? amount = double.tryParse(
                      paymentAmountController.text,
                    );
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                        ),
                      );
                      return;
                    }

                    // Add to payment schedule
                    setState(() {
                      paymentSchedule.add({
                        'dueDate': dueDateController.text,
                        'amount': amount,
                        'paid': false,
                      });

                      // Clear the form
                      dueDateController.clear();
                      paymentAmountController.clear();
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                // Validate inputs
                if (descriptionController.text.isEmpty ||
                    amountController.text.isEmpty ||
                    paymentSchedule.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please fill all required fields and add at least one payment schedule item',
                      ),
                    ),
                  );
                  return;
                }

                // Parse amount
                double? totalAmount = double.tryParse(amountController.text);
                if (totalAmount == null || totalAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid total amount'),
                    ),
                  );
                  return;
                }

                // Calculate total from payment schedule
                double scheduleTotal = paymentSchedule.fold(
                  0.0,
                  (sum, item) => sum + (item['amount'] as double),
                );

                // Verify that payment schedule matches total amount
                if ((scheduleTotal - totalAmount).abs() > 0.01) {
                  bool proceed =
                      await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Amount Mismatch'),
                          content: Text(
                            'The sum of payment schedule (₱${scheduleTotal.toStringAsFixed(2)}) ' +
                                'does not match the total amount (₱${totalAmount.toStringAsFixed(2)}). ' +
                                'Do you want to proceed anyway?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Proceed Anyway'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (!proceed) return;
                }

                try {
                  // Create billing document
                  final billingData = {
                    'userUID': studentId,
                    'description': descriptionController.text,
                    'summary': summaryController.text,
                    'amount': totalAmount,
                    'remainingBalance':
                        totalAmount, // Initial remaining balance is the total amount
                    'paymentDueDates': paymentSchedule,
                    'createdAt': FieldValue.serverTimestamp(),
                  };

                  await FirebaseFirestore.instance
                      .collection('billings')
                      .add(billingData);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Billing added successfully')),
                  );
                  Navigator.pop(context);
                  _loadStudentData(); // Refresh the list
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding billing: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to the _AccountingScreenState class
  void _showRecordPaymentDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Record Payment for ${student['username']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select payments to mark as \npaid/unpaid:'),
              const SizedBox(height: 16),
              if (student['paymentDueDates'] != null &&
                  student['paymentDueDates'].isNotEmpty)
                ...List.generate(student['paymentDueDates'].length, (index) {
                  final payment = student['paymentDueDates'][index];
                  final dueDate = payment['dueDate'] ?? '';
                  final amount = payment['amount'] ?? 0;
                  final isPaid = payment['paid'] ?? false;

                  return CheckboxListTile(
                    title: Text('Due: $dueDate'),
                    subtitle: Text('₱${amount.toStringAsFixed(2)}'),
                    value: isPaid,
                    onChanged: (value) async {
                      try {
                        // Update the payment status
                        final billingId = student['id'];
                        final updatedPayments = List.from(
                          student['paymentDueDates'],
                        );
                        updatedPayments[index]['paid'] = value;

                        if (value == true) {
                          updatedPayments[index]['paidDate'] = DateFormat(
                            'yyyy-MM-dd',
                          ).format(DateTime.now());
                        } else {
                          // Remove paidDate if unmarking as paid
                          updatedPayments[index].remove('paidDate');
                        }

                        await FirebaseFirestore.instance
                            .collection('billings')
                            .doc(billingId)
                            .update({'paymentDueDates': updatedPayments});

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value == true
                                  ? 'Payment recorded successfully'
                                  : 'Payment unmarked successfully',
                            ),
                          ),
                        );
                        Navigator.pop(context);
                        _loadStudentData(); // Refresh the list
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating payment: $e')),
                        );
                      }
                    },
                  );
                })
              else
                const Text('No payment schedule available'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditBillingDialog(Map<String, dynamic> student) {
    final descriptionController = TextEditingController(
      text: student['description'] ?? '',
    );
    final summaryController = TextEditingController(
      text: student['summary'] ?? '',
    );
    final amountController = TextEditingController(
      text: (student['amount'] ?? 0).toString(),
    );

    // Create a copy of the payment schedule for editing
    List<Map<String, dynamic>> paymentSchedule = [];
    if (student['paymentDueDates'] != null) {
      for (var payment in student['paymentDueDates']) {
        paymentSchedule.add(Map<String, dynamic>.from(payment));
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Billing for ${student['username']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g., Tuition fees',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: summaryController,
                  decoration: const InputDecoration(
                    labelText: 'Summary',
                    hintText: 'e.g., First semester enrollment',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Total Amount (₱)',
                    hintText: 'e.g., 10000',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Payment Schedule',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: Color(0xFF4CAF50),
                      ),
                      onPressed: () async {
                        final dueDate = await _selectDate(context);
                        if (dueDate != null) {
                          final amountResult = await _showAmountInputDialog(
                            context,
                          );
                          if (amountResult != null) {
                            setState(() {
                              paymentSchedule.add({
                                'dueDate': dueDate,
                                'amount': amountResult,
                                'paid': false,
                              });
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Display payment schedule items
                if (paymentSchedule.isNotEmpty) ...[
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
                              SizedBox(width: 40),
                            ],
                          ),
                        ),

                        // Table rows
                        ...List.generate(paymentSchedule.length, (i) {
                          final payment = paymentSchedule[i];
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
                                Expanded(child: Text(payment['dueDate'] ?? '')),
                                Expanded(
                                  child: Text(
                                    '₱${(payment['amount'] ?? 0).toStringAsFixed(2)}',
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        paymentSchedule.removeAt(i);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ] else
                  const Text('No payment schedule items added yet'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                // Validate inputs
                if (descriptionController.text.isEmpty ||
                    amountController.text.isEmpty ||
                    paymentSchedule.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please fill all required fields and add at least one payment schedule item',
                      ),
                    ),
                  );
                  return;
                }

                // Parse amount
                double? totalAmount = double.tryParse(amountController.text);
                if (totalAmount == null || totalAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid total amount'),
                    ),
                  );
                  return;
                }

                try {
                  // Update the billing record
                  await FirebaseFirestore.instance
                      .collection('billings')
                      .doc(student['id'])
                      .update({
                        'description': descriptionController.text,
                        'summary': summaryController.text,
                        'amount': totalAmount,
                        'paymentDueDates': paymentSchedule,
                      });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Billing information updated successfully'),
                    ),
                  );
                  Navigator.pop(context);
                  _loadStudentData(); // Refresh the list
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating billing: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Billing'),
        content: Text(
          'Are you sure you want to delete the billing record for ${student['username']}? ' +
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                final billingId = student['id'];

                await FirebaseFirestore.instance
                    .collection('billings')
                    .doc(billingId)
                    .delete();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Billing deleted successfully')),
                );
                Navigator.pop(context);
                _loadStudentData(); // Refresh the list
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting billing: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
