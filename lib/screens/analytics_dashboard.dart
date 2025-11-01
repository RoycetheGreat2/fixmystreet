import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  bool _isAdmin = false;
  Map<String, int> _statusCounts = {};
  Map<String, int> _categoryCounts = {};
  int _totalReports = 0;
  int _myReports = 0;
  int _resolvedToday = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if admin
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    setState(() {
      _isAdmin = userDoc.data()?['isAdmin'] ?? false;
    });

    // Load report statistics
    final reportsSnapshot = await FirebaseFirestore.instance
        .collection('reports')
        .get();

    Map<String, int> statusMap = {};
    Map<String, int> categoryMap = {};
    int myReportsCount = 0;
    int resolvedTodayCount = 0;
    final today = DateTime.now();

    for (var doc in reportsSnapshot.docs) {
      final data = doc.data();
      
      // Count by status
      final status = data['status'] ?? 'Pending';
      statusMap[status] = (statusMap[status] ?? 0) + 1;

      // Count by category/title
      final title = data['title'] ?? 'Other';
      categoryMap[title] = (categoryMap[title] ?? 0) + 1;

      // Count user's reports
      if (data['userId'] == user.uid) {
        myReportsCount++;
      }

      // Count resolved today
      if (status == 'Resolved' && data['timestamp'] != null) {
        final reportDate = (data['timestamp'] as Timestamp).toDate();
        if (reportDate.year == today.year &&
            reportDate.month == today.month &&
            reportDate.day == today.day) {
          resolvedTodayCount++;
        }
      }
    }

    setState(() {
      _statusCounts = statusMap;
      _categoryCounts = categoryMap;
      _totalReports = reportsSnapshot.docs.length;
      _myReports = myReportsCount;
      _resolvedToday = resolvedTodayCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1025A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Reports',
                      _totalReports.toString(),
                      Icons.report,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'My Reports',
                      _myReports.toString(),
                      Icons.person,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Pending',
                      (_statusCounts['Pending'] ?? 0).toString(),
                      Icons.pending,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Resolved Today',
                      _resolvedToday.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Status Distribution Chart
              Text(
                'Reports by Status',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _statusCounts.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No data available'),
                        ),
                      )
                    : SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: _buildPieChartSections(),
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 20),

              // Legend
              if (_statusCounts.isNotEmpty) ...[
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildLegendItem('Pending', Colors.orange),
                    _buildLegendItem('In Progress', Colors.blue),
                    _buildLegendItem('Resolved', Colors.green),
                  ],
                ),
              ],

              const SizedBox(height: 30),

              // Top Categories
              Text(
                'Top Report Categories',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _categoryCounts.isEmpty
                    ? const Center(child: Text('No data available'))
                    : Column(
                        children: _buildTopCategories(),
                      ),
              ),

              const SizedBox(height: 30),

              // Response Time (if admin)
              if (_isAdmin) ...[
                Text(
                  'Admin Statistics',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  'Average Response Time',
                  '2.5 days',
                  Icons.timer,
                  Colors.purple,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 30),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final pending = _statusCounts['Pending'] ?? 0;
    final inProgress = _statusCounts['In Progress'] ?? 0;
    final resolved = _statusCounts['Resolved'] ?? 0;
    final total = pending + inProgress + resolved;

    if (total == 0) return [];

    return [
      PieChartSectionData(
        value: pending.toDouble(),
        title: '${((pending / total) * 100).toStringAsFixed(0)}%',
        color: Colors.orange,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: inProgress.toDouble(),
        title: '${((inProgress / total) * 100).toStringAsFixed(0)}%',
        color: Colors.blue,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: resolved.toDouble(),
        title: '${((resolved / total) * 100).toStringAsFixed(0)}%',
        color: Colors.green,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  List<Widget> _buildTopCategories() {
    final sorted = _categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top5 = sorted.take(5).toList();

    return top5.map((entry) {
      final percentage = (_categoryCounts[entry.key]! / _totalReports * 100);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: entry.value / _totalReports,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1025A1),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}