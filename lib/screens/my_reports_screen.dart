// ============================================================================
// FILE 2: lib/screens/my_reports_screen.dart
// ============================================================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'report_details.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _statusFilter = 'All';

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green.shade400;
      case 'in progress':
      case 'in-progress':
        return Colors.blue.shade400;
      case 'pending':
        return Colors.orange.shade400;
      default:
        return Colors.grey;
    }
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(timestamp.toDate());
    
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} month(s) ago';
    if (diff.inDays > 0) return '${diff.inDays} day(s) ago';
    if (diff.inHours > 0) return '${diff.inHours} hour(s) ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minute(s) ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1025A1),
          title: Text('My Reports', style: GoogleFonts.poppins(color: Colors.white)),
        ),
        body: const Center(
          child: Text('Please log in to view your reports'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFD7E3E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1025A1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'My Reports',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Filter dropdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _statusFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All')),
              const PopupMenuItem(value: 'Pending', child: Text('Pending')),
              const PopupMenuItem(value: 'In Progress', child: Text('In Progress')),
              const PopupMenuItem(value: 'Resolved', child: Text('Resolved')),
            ],
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('userId', isEqualTo: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No reports yet',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start by submitting your first report!',
                    style: GoogleFonts.inter(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // Filter reports by status
          var reports = snapshot.data!.docs;
          if (_statusFilter != 'All') {
            reports = reports.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] == _statusFilter;
            }).toList();
          }

          // Sort by timestamp (newest first)
          reports.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['timestamp'] as Timestamp?;
            final bTime = bData['timestamp'] as Timestamp?;
            
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            
            return bTime.compareTo(aTime);
          });

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.filter_list_off, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No $_statusFilter reports',
                    style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Stats header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Total', snapshot.data!.docs.length.toString(), Colors.blue),
                    _buildStatItem(
                      'Pending',
                      snapshot.data!.docs.where((d) => (d.data() as Map)['status'] == 'Pending').length.toString(),
                      Colors.orange,
                    ),
                    _buildStatItem(
                      'Resolved',
                      snapshot.data!.docs.where((d) => (d.data() as Map)['status'] == 'Resolved').length.toString(),
                      Colors.green,
                    ),
                  ],
                ),
              ),

              // Reports list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final data = report.data() as Map<String, dynamic>;

                    return GestureDetector(
                      onTap: () {
                        // Navigate to report details
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReportDetailsScreen(reportData: report),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: data['imageUrl'] != null && data['imageUrl'].isNotEmpty
                                  ? Image.network(
                                      data['imageUrl'],
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 70,
                                        height: 70,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    )
                                  : Container(
                                      width: 70,
                                      height: 70,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image),
                                    ),
                            ),

                            const SizedBox(width: 12),

                            // Text Section
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] ?? 'Untitled',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),

                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          data['landmark'] ?? 'No location',
                                          style: GoogleFonts.inter(
                                            color: Colors.grey.shade700,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  Row(
                                    children: [
                                      Icon(Icons.access_time,
                                          size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        _timeAgo(data['timestamp']),
                                        style: GoogleFonts.inter(
                                          color: Colors.grey.shade700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Upvotes
                                  if (data['upvotes'] != null && data['upvotes'] > 0) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.thumb_up,
                                            size: 16, color: Colors.red.shade400),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${data['upvotes']} upvotes',
                                          style: GoogleFonts.inter(
                                            color: Colors.grey.shade700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(data['status'] ?? 'Pending'),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                data['status'] ?? 'Pending',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
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
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}