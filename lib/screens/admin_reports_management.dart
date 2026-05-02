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
  String _sortBy = 'Recent'; // Recent, Most Upvoted, Least Upvoted
  String _timeFilter = 'All Time'; // All Time, Last 24 Hours, Last 7 Days, Last Month
  String _locationFilter = 'All Locations';
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  List<String> _availableLocations = ['All Locations'];
  bool _loadingLocations = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableLocations() async {
    setState(() => _loadingLocations = true);
    
    try {
      final reportsSnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .get();

      Set<String> locations = {'All Locations'};
      
      for (var doc in reportsSnapshot.docs) {
        final data = doc.data();
        final landmark = data['landmark']?.toString().trim();
        if (landmark != null && landmark.isNotEmpty) {
          locations.add(landmark);
        }
      }

      setState(() {
        _availableLocations = locations.toList()..sort();
        _loadingLocations = false;
      });
    } catch (e) {
      print('Error loading locations: $e');
      setState(() => _loadingLocations = false);
    }
  }

  DateTime? _getTimeFilterDate() {
    final now = DateTime.now();
    switch (_timeFilter) {
      case 'Last 24 Hours':
        return now.subtract(const Duration(hours: 24));
      case 'Last 7 Days':
        return now.subtract(const Duration(days: 7));
      case 'Last Month':
        return now.subtract(const Duration(days: 30));
      default:
        return null;
    }
  }

  List<DocumentSnapshot> _filterAndSortReports(List<DocumentSnapshot> reports) {
    var filtered = reports;

    // Apply status filter
    if (_statusFilter != 'All') {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['status'] == _statusFilter;
      }).toList();
    }

    // Apply time filter
    final timeFilterDate = _getTimeFilterDate();
    if (timeFilterDate != null) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) return false;
        return timestamp.toDate().isAfter(timeFilterDate);
      }).toList();
    }

    // Apply location filter
    if (_locationFilter != 'All Locations') {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final landmark = data['landmark']?.toString().trim() ?? '';
        return landmark == _locationFilter;
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final title = (data['title'] ?? '').toString().toLowerCase();
        final description = (data['description'] ?? '').toString().toLowerCase();
        final username = (data['username'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery) || 
               description.contains(_searchQuery) ||
               username.contains(_searchQuery);
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      switch (_sortBy) {
        case 'Most Upvoted':
          final aUpvotes = aData['upvotes'] ?? 0;
          final bUpvotes = bData['upvotes'] ?? 0;
          return bUpvotes.compareTo(aUpvotes); // Descending

        case 'Least Upvoted':
          final aUpvotes = aData['upvotes'] ?? 0;
          final bUpvotes = bData['upvotes'] ?? 0;
          return aUpvotes.compareTo(bUpvotes); // Ascending

        case 'Recent':
        default:
          final aTime = aData['timestamp'] as Timestamp?;
          final bTime = bData['timestamp'] as Timestamp?;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return -1;
          if (bTime == null) return 1;
          
          return bTime.compareTo(aTime); // Most recent first
      }
    });

    return filtered;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Advanced Filters', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sort By
              Text('Sort By', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Recent', 'Most Upvoted', 'Least Upvoted'].map((sort) {
                  return ChoiceChip(
                    label: Text(sort),
                    selected: _sortBy == sort,
                    onSelected: (selected) {
                      setState(() => _sortBy = sort);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),

              // Time Filter
              Text('Time Period', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['All Time', 'Last 24 Hours', 'Last 7 Days', 'Last Month'].map((time) {
                  return ChoiceChip(
                    label: Text(time),
                    selected: _timeFilter == time,
                    onSelected: (selected) {
                      setState(() => _timeFilter = time);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),

              // Location Filter
              Text('Location', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _locationFilter,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                isExpanded: true,
                items: _availableLocations.map((location) {
                  return DropdownMenuItem(
                    value: location,
                    child: Text(
                      location,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _locationFilter = value);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _sortBy = 'Recent';
                _timeFilter = 'All Time';
                _locationFilter = 'All Locations';
              });
              Navigator.pop(context);
            },
            child: const Text('Reset All'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReport(String reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting report: $e')),
          );
        }
      }
    }
  }

  Future<void> _changeStatus(String reportId, String currentStatus) async {
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Pending'),
              leading: Radio<String>(
                value: 'Pending',
                groupValue: currentStatus,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
            ListTile(
              title: const Text('In Progress'),
              leading: Radio<String>(
                value: 'In Progress',
                groupValue: currentStatus,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
            ListTile(
              title: const Text('Resolved'),
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status updated to $newStatus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating status: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteComment(String reportId, String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting comment: $e')),
          );
        }
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
            padding: const EdgeInsets.all(20),
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
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                Text(
                  data['title'] ?? 'Untitled',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.thumb_up, size: 16, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            '${data['upvotes'] ?? 0}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  data['description'] ?? 'No description',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 15),
                if (data['landmark'] != null && data['landmark'].isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['landmark'],
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  'By: ${data['username'] ?? 'Anonymous'}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _changeStatus(report.id, data['status'] ?? 'Pending');
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Change Status'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteReport(report.id);
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  'Comments',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reports')
                      .doc(report.id)
                      .collection('comments')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Text('No comments', style: TextStyle(color: Colors.grey));
                    }

                    return Column(
                      children: snapshot.data!.docs.map((commentDoc) {
                        final commentData = commentDoc.data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(commentData['text'] ?? ''),
                            subtitle: Text('By: ${commentData['username'] ?? 'Anonymous'}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
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
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableLocations,
            tooltip: 'Refresh locations',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title, description, or username...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
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
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Status Filter
                DropdownButton<String>(
                  value: _statusFilter,
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
                const SizedBox(width: 16),
                
                // Advanced Filters Button
                OutlinedButton.icon(
                  onPressed: _showFilterDialog,
                  icon: const Icon(Icons.tune),
                  label: Text(
                    'Filters${_sortBy != 'Recent' || _timeFilter != 'All Time' || _locationFilter != 'All Locations' ? ' (Active)' : ''}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _sortBy != 'Recent' || _timeFilter != 'All Time' || _locationFilter != 'All Locations'
                        ? Colors.blue
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Active Filters Display
          if (_sortBy != 'Recent' || _timeFilter != 'All Time' || _locationFilter != 'All Locations')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_sortBy != 'Recent')
                    Chip(
                      label: Text('Sort: $_sortBy'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _sortBy = 'Recent'),
                    ),
                  if (_timeFilter != 'All Time')
                    Chip(
                      label: Text(_timeFilter),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _timeFilter = 'All Time'),
                    ),
                  if (_locationFilter != 'All Locations')
                    Chip(
                      label: Text('📍 $_locationFilter'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _locationFilter = 'All Locations'),
                    ),
                ],
              ),
            ),
          
          const SizedBox(height: 8),
          
          // Reports List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No reports found'));
                }

                var reports = _filterAndSortReports(snapshot.data!.docs);

                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No matching reports found'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _statusFilter = 'All';
                              _sortBy = 'Recent';
                              _timeFilter = 'All Time';
                              _locationFilter = 'All Locations';
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                          child: const Text('Clear all filters'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final data = report.data() as Map<String, dynamic>;
                    final upvotes = data['upvotes'] ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Stack(
                          children: [
                            data['imageUrl'] != null && data['imageUrl'].isNotEmpty
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
                                    child: const Icon(Icons.image),
                                  ),
                            if (upvotes > 0)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.thumb_up, size: 10, color: Colors.white),
                                      const SizedBox(width: 2),
                                      Text(
                                        '$upvotes',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          data['title'] ?? 'Untitled',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['username'] ?? 'Anonymous'),
                            if (data['landmark'] != null && data['landmark'].isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 12, color: Colors.grey),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      data['landmark'],
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Text('View Details'),
                            ),
                            const PopupMenuItem(
                              value: 'status',
                              child: Text('Change Status'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                          onSelected: (value) {
                            switch (value) {
                              case 'view':
                                _showReportDetails(report);
                                break;
                              case 'status':
                                _changeStatus(report.id, data['status'] ?? 'Pending');
                                break;
                              case 'delete':
                                _deleteReport(report.id);
                                break;
                            }
                          },
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