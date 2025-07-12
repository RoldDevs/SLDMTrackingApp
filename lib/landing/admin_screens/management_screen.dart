import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _approvals = [];
  List<Map<String, dynamic>> _users = [];

  // Current selected section
  String _currentSection = 'Announcements';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Load data based on current section
    if (_currentSection == 'Announcements') {
      await _loadAnnouncements();
    } else if (_currentSection == 'Approvals') {
      await _loadApprovals();
    } else if (_currentSection == 'Masterlist') {
      await _loadUsers();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadAnnouncements() async {
    try {
      final snapshot = await _firestore
          .collection('announcements')
          .orderBy('timestamp', descending: true)
          .get();

      final announcements = snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();

      setState(() {
        _announcements = announcements;
      });
    } catch (e) {
      print('Error loading announcements: $e');
    }
  }

  Future<void> _loadApprovals() async {
    try {
      final snapshot = await _firestore
          .collection('forApproval')
          .orderBy('timestamp', descending: true)
          .get();

      final approvals = snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();

      // Ensure each approval has a studentName
      for (var approval in approvals) {
        if (approval['studentName'] == null ||
            approval['studentName'].isEmpty) {
          // Try to fetch the student name if it's missing
          if (approval['userUID'] != null) {
            try {
              final studentDoc = await _firestore
                  .collection('students')
                  .doc(approval['userUID'])
                  .get();

              if (studentDoc.exists) {
                approval['studentName'] =
                    studentDoc.data()?['username'] ?? 'Unknown';
              }
            } catch (e) {
              print('Error fetching student name: $e');
            }
          }
        }
      }

      setState(() {
        _approvals = approvals;
      });
    } catch (e) {
      print('Error loading approvals: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await _firestore.collection('students').get();

      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();

      setState(() {
        _users = users;
      });
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    try {
      await _firestore.collection('announcements').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement deleted successfully')),
      );
      _loadAnnouncements(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting announcement: $e')),
      );
    }
  }

  void _showAnnouncementDialog({Map<String, dynamic>? announcement}) {
    final titleController = TextEditingController(
      text: announcement?['title'] ?? '',
    );
    final contentController = TextEditingController(
      text: announcement?['content'] ?? '',
    );
    var isEvent = announcement?['isEvent'] ?? false;
    final eventDateController = TextEditingController(
      text: announcement?['eventDate'] ?? '',
    );
    final eventLocationController = TextEditingController(
      text: announcement?['eventLocation'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              announcement == null ? 'New Announcement' : 'Edit Announcement',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isEvent,
                        onChanged: (value) {
                          setState(() => isEvent = value ?? false);
                        },
                      ),
                      const Text('This is an event'),
                    ],
                  ),
                  if (isEvent) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: eventDateController,
                      decoration: const InputDecoration(
                        labelText: 'Event Date (YYYY-MM-DD)',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null) {
                          eventDateController.text = DateFormat(
                            'yyyy-MM-dd',
                          ).format(date);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: eventLocationController,
                      decoration: const InputDecoration(
                        labelText: 'Event Location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (titleController.text.isEmpty ||
                      contentController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Title and content are required'),
                      ),
                    );
                    return;
                  }

                  if (isEvent && eventDateController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Event date is required')),
                    );
                    return;
                  }

                  try {
                    final data = {
                      'title': titleController.text,
                      'content': contentController.text,
                      'timestamp': FieldValue.serverTimestamp(),
                      'isEvent': isEvent,
                      'eventDate': isEvent ? eventDateController.text : null,
                      'eventLocation': isEvent
                          ? eventLocationController.text
                          : null,
                    };

                    if (announcement == null) {
                      // Create new announcement
                      await _firestore.collection('announcements').add(data);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Announcement created successfully'),
                        ),
                      );
                    } else {
                      // Update existing announcement
                      await _firestore
                          .collection('announcements')
                          .doc(announcement['id'])
                          .update(data);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Announcement updated successfully'),
                        ),
                      );
                    }

                    Navigator.pop(context);
                    _loadAnnouncements(); // Refresh the list
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving announcement: $e')),
                    );
                  }
                },
                child: Text(announcement == null ? 'Create' : 'Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Method to approve or reject student billing changes
  Future<void> _handleApproval(
    Map<String, dynamic> approval,
    bool isApproved,
  ) async {
    try {
      if (isApproved) {
        // Get the original billing document
        final billingDoc = await _firestore
            .collection('billings')
            .doc(approval['billingId'])
            .get();

        if (billingDoc.exists) {
          final billingData = billingDoc.data()!;

          // Update the payment status based on the approval
          List<dynamic> paymentDueDates = List.from(
            billingData['paymentDueDates'],
          );
          int paymentIndex = approval['paymentIndex'];

          if (paymentIndex >= 0 && paymentIndex < paymentDueDates.length) {
            // Update the payment status
            paymentDueDates[paymentIndex]['paid'] = approval['newPaidStatus'];

            if (approval['newPaidStatus'] == true) {
              paymentDueDates[paymentIndex]['paidDate'] = DateFormat(
                'yyyy-MM-dd',
              ).format(DateTime.now());
            } else {
              // Remove paidDate if unmarking as paid
              paymentDueDates[paymentIndex].remove('paidDate');
            }

            // Update the billing document
            await _firestore
                .collection('billings')
                .doc(approval['billingId'])
                .update({'paymentDueDates': paymentDueDates});
          }
        }
      }

      // Delete the approval document regardless of approval status
      await _firestore.collection('forApproval').doc(approval['id']).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isApproved ? 'Change approved successfully' : 'Change rejected',
          ),
        ),
      );

      // Refresh the approvals list
      _loadApprovals();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error processing approval: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentSection),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF4CAF50)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text(
                    'Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Admin Dashboard',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.announcement),
              title: const Text('Announcements'),
              selected: _currentSection == 'Announcements',
              onTap: () {
                setState(() {
                  _currentSection = 'Announcements';
                });
                Navigator.pop(context);
                _loadData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.approval),
              title: const Text('Approvals'),
              selected: _currentSection == 'Approvals',
              onTap: () {
                setState(() {
                  _currentSection = 'Approvals';
                });
                Navigator.pop(context);
                _loadData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Masterlist'),
              selected: _currentSection == 'Masterlist',
              onTap: () {
                setState(() {
                  _currentSection = 'Masterlist';
                });
                Navigator.pop(context);
                _loadData();
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildCurrentSection(),
      floatingActionButton: _currentSection == 'Announcements'
          ? FloatingActionButton(
              onPressed: () => _showAnnouncementDialog(),
              backgroundColor: const Color(0xFF4CAF50),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildCurrentSection() {
    switch (_currentSection) {
      case 'Announcements':
        return _buildAnnouncementsSection();
      case 'Approvals':
        return _buildApprovalsSection();
      case 'Masterlist':
        return _buildMasterlistSection();
      default:
        return _buildAnnouncementsSection();
    }
  }

  Widget _buildAnnouncementsSection() {
    return _announcements.isEmpty
        ? const Center(child: Text('No announcements yet'))
        : RefreshIndicator(
            onRefresh: _loadAnnouncements,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _announcements.length,
              itemBuilder: (context, index) {
                final announcement = _announcements[index];
                final isEvent = announcement['isEvent'] ?? false;
                final timestamp = announcement['timestamp'] as Timestamp?;
                final formattedDate = timestamp != null
                    ? DateFormat('MMM dd, yyyy').format(timestamp.toDate())
                    : 'Unknown date';

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title and badge
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isEvent
                              ? Colors.amber.shade100
                              : Colors.blue.shade100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                announcement['title'] ?? 'Untitled',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isEvent
                                    ? Colors.amber.shade700
                                    : Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isEvent ? 'Event' : 'Announcement',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(announcement['content'] ?? ''),
                            const SizedBox(height: 16),
                            if (isEvent) ...[
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Date: ${announcement['eventDate'] ?? 'Not specified'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Location: ${announcement['eventLocation'] ?? 'Not specified'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16),
                                const SizedBox(width: 8),
                                Text('Posted: $formattedDate'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Actions
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAnnouncementDialog(
                                announcement: announcement,
                              ),
                              color: Colors.blue,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () =>
                                  _deleteAnnouncement(announcement['id']),
                              color: Colors.red,
                            ),
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

  Widget _buildApprovalsSection() {
    return _approvals.isEmpty
        ? const Center(child: Text('No pending approvals'))
        : RefreshIndicator(
            onRefresh: _loadApprovals,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _approvals.length,
              itemBuilder: (context, index) {
                final approval = _approvals[index];
                final timestamp = approval['timestamp'] as Timestamp?;
                final formattedDate = timestamp != null
                    ? DateFormat('MMM dd, yyyy').format(timestamp.toDate())
                    : 'Unknown date';
                final newPaidStatus = approval['newPaidStatus'] ?? false;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, color: Color(0xFF4CAF50)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    approval['studentName'] ??
                                        'Unknown Student',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Email: ${approval['studentEmail'] ?? 'Unknown'}',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(height: 8),
                        Text(
                          'Payment Status Change Request:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Due Date: ${approval['dueDate'] ?? 'Unknown'}',
                              ),
                              Text(
                                'Amount: ₱${(approval['amount'] ?? 0).toStringAsFixed(2)}',
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Status Change: '),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: newPaidStatus
                                          ? Colors.green.shade100
                                          : Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      newPaidStatus
                                          ? 'Mark as Paid'
                                          : 'Mark as Overdue', // Changed from 'Mark as Unpaid' to 'Mark as Overdue'
                                      style: TextStyle(
                                        color: newPaidStatus
                                            ? Colors.green.shade800
                                            : Colors.red.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16),
                            const SizedBox(width: 8),
                            Text('Requested: $formattedDate'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _handleApproval(approval, false),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _handleApproval(approval, true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
  }

  Widget _buildMasterlistSection() {
    return _users.isEmpty
        ? const Center(child: Text('No users found'))
        : RefreshIndicator(
            onRefresh: _loadUsers,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF4CAF50),
                      child: Text(
                        user['username']?.substring(0, 1).toUpperCase() ?? '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(user['username'] ?? 'Unknown'),
                    subtitle: Text(user['email'] ?? ''),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: user['isAdmin'] == true
                            ? Colors.blue.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user['isAdmin'] == true ? 'Admin' : 'Student',
                        style: TextStyle(
                          color: user['isAdmin'] == true
                              ? Colors.blue.shade800
                              : Colors.green.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
  }
}
