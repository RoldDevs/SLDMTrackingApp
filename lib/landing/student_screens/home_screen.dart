import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncementsAndEvents();
  }

  Future<void> _loadAnnouncementsAndEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('announcements')
          .orderBy('timestamp', descending: true)
          .get();

      final allItems = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Separate announcements and events
      final announcements = allItems.where((item) => !(item['isEvent'] ?? false)).toList();
      final events = allItems.where((item) => item['isEvent'] ?? false).toList();

      setState(() {
        _announcements = announcements;
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading announcements and events: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Home'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnnouncementsAndEvents,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF46923c),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/sldm_logo.png',
                              height: 60,
                              width: 60,
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome to SLDM',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Stay updated with the latest announcements and events',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Upcoming Events section
                      if (_events.isNotEmpty) ...[  
                        const Text(
                          'Upcoming Events',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _events.length,
                            itemBuilder: (context, index) {
                              final event = _events[index];
                              final timestamp = event['timestamp'] as Timestamp?;
                              final formattedDate = timestamp != null
                                  ? DateFormat('MMM dd, yyyy').format(timestamp.toDate())
                                  : 'Unknown date';
                              
                              return Container(
                                width: 280,
                                margin: const EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade200,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                          topRight: Radius.circular(12),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.event),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              event['title'] ?? 'Untitled Event',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              event['content'] ?? '',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const Spacer(),
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today, size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  event['eventDate'] ?? 'Date not specified',
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on, size: 16),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    event['eventLocation'] ?? 'Location not specified',
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
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
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Announcements section
                      const Text(
                        'Announcements',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _announcements.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No announcements available'),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _announcements.length,
                              itemBuilder: (context, index) {
                                final announcement = _announcements[index];
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
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.announcement),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                announcement['title'] ?? 'Untitled',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(announcement['content'] ?? ''),
                                            const SizedBox(height: 16),
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
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}