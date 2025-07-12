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

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
    });

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
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading announcements: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements & Events'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAnnouncementDialog(),
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add),
      ),
    );
  }
}
