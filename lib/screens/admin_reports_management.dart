import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class AdminReportsManagement extends StatefulWidget {
  const AdminReportsManagement({super.key});

  @override
  State<AdminReportsManagement> createState() => _AdminReportsManagementState();
}

class _AdminReportsManagementState extends State<AdminReportsManagement> {
  String _statusFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteReport(String reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Report'),
        content: Text('Are you sure you want to delete this report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final comments = await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .collection('comments')
            .get();

        for (var doc in comments.docs) {
          await doc.reference.delete();
        }

        await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting report: $e')),
        );
      }
    }
  }

  Future<void> _changeStatus(String reportId, String currentStatus) async {
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Pending'),
              leading: Radio<String>(
                value: 'Pending',
                groupValue: currentStatus,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
            ListTile(
              title: Text('In Progress'),
              leading: Radio<String>(
                value: 'In Progress',
                groupValue: currentStatus,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
            ListTile(
              title: Text('Resolved'),
              leading: Radio<String>(
                value: 'Resolved',
                groupValue: currentStatus,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
          ],
        ),
      ),
    );

    if (newStatus != null && newStatus != currentStatus) {
      try {
        final reportDoc = await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .get();
        
        final reportData = reportDoc.data() as Map<String, dynamic>;
        final userId = reportData['userId'];
        final reportTitle = reportData['title'] ?? 'Your report';

        await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .update({'status': newStatus});

        if (userId != null) {
          await NotificationService.sendStatusChangeNotification(
            userId: userId,
            reportId: reportId,
            reportTitle: reportTitle,
            newStatus: newStatus,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Future<void> _deleteComment(String reportId, String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Comment'),
        content: Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .collection('comments')
            .doc(commentId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting comment: $e')),
        );
      }
    }
  }

  void _showReportDetails(DocumentSnapshot report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          final data = report.data() as Map<String, dynamic>;
          return Container(
            padding: EdgeInsets.all(20),
            child: ListView(
              controller: scrollController,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Report Details',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                if (data['imageUrl'] != null && data['imageUrl'].isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      data['imageUrl'],
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                SizedBox(height: 20),
                Text(
                  data['title'] ?? 'Untitled',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: data['status'] == 'Pending'
                        ? Colors.orange
                        : data['status'] == 'In Progress'
                            ? Colors.blue
                            : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data['status'] ?? 'Pending',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  data['description'] ?? 'No description',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 15),
                Text(
                  'By: ${data['username'] ?? 'Anonymous'}',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _changeStatus(report.id, data['status'] ?? 'Pending');
                        },
                        icon: Icon(Icons.edit),
                        label: Text('Change Status'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteReport(report.id);
                        },
                        icon: Icon(Icons.delete),
                        label: Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30),
                Text(
                  'Comments',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reports')
                      .doc(report.id)
                      .collection('comments')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Text('No comments', style: TextStyle(color: Colors.grey));
                    }

                    return Column(
                      children: snapshot.data!.docs.map((commentDoc) {
                        final commentData = commentDoc.data() as Map<String, dynamic>;
                        return Card(
                          margin: EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(commentData['text'] ?? ''),
                            subtitle: Text('By: ${commentData['username'] ?? 'Anonymous'}'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteComment(report.id, commentDoc.id);
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Reports',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1025A1),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          // Filter Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text('Filter: ', style: TextStyle(fontSize: 16)),
                SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    isExpanded: true,
                    items: ['All', 'Pending', 'In Progress', 'Resolved']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _statusFilter = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          
          // Reports List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No reports found'));
                }

                var reports = snapshot.data!.docs;

                // Apply status filter
                if (_statusFilter != 'All') {
                  reports = reports.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['status'] == _statusFilter;
                  }).toList();
                }

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  reports = reports.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = (data['title'] ?? '').toString().toLowerCase();
                    return title.contains(_searchQuery);
                  }).toList();
                }

                // Sort by timestamp
                reports.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['timestamp'] as Timestamp?;
                  final bTime = bData['timestamp'] as Timestamp?;
                  
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return -1;
                  if (bTime == null) return 1;
                  
                  return bTime.compareTo(aTime);
                });

                if (reports.isEmpty) {
                  return Center(child: Text('No matching reports found'));
                }

                return ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final data = report.data() as Map<String, dynamic>;

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: data['imageUrl'] != null && data['imageUrl'].isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  data['imageUrl'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.image),
                              ),
                        title: Text(
                          data['title'] ?? 'Untitled',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['username'] ?? 'Anonymous'),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: data['status'] == 'Pending'
                                    ? Colors.orange
                                    : data['status'] == 'In Progress'
                                        ? Colors.blue
                                        : Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                data['status'] ?? 'Pending',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: Text('View Details'),
                              onTap: () {
                                Future.delayed(
                                  Duration.zero,
                                  () => _showReportDetails(report),
                                );
                              },
                            ),
                            PopupMenuItem(
                              child: Text('Change Status'),
                              onTap: () {
                                Future.delayed(
                                  Duration.zero,
                                  () => _changeStatus(report.id, data['status'] ?? 'Pending'),
                                );
                              },
                            ),
                            PopupMenuItem(
                              child: Text('Delete', style: TextStyle(color: Colors.red)),
                              onTap: () {
                                Future.delayed(
                                  Duration.zero,
                                  () => _deleteReport(report.id),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}