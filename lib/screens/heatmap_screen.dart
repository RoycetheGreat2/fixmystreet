import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  List<Map<String, dynamic>> _reports = [];
  Map<String, int> _cityReports = {};
  Map<String, int> _barangayReports = {};
  bool _loading = true;
  String _groupBy = 'city'; // city or barangay

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .get();

      Map<String, int> cityCount = {};
      Map<String, int> barangayCount = {};

      final reports = snapshot.docs.map((doc) {
        final data = doc.data();
        
        // Count by city
        final city = data['location']?['city'] ?? 'Unknown';
        cityCount[city] = (cityCount[city] ?? 0) + 1;

        // Count by barangay
        final barangay = data['location']?['barangay'] ?? 'Unknown';
        barangayCount[barangay] = (barangayCount[barangay] ?? 0) + 1;

        return {
          'id': doc.id,
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'status': data['status'] ?? 'Pending',
          'city': city,
          'barangay': barangay,
        };
      }).where((report) {
        return report['latitude'] != null && report['longitude'] != null;
      }).toList();

      setState(() {
        _reports = reports;
        _cityReports = cityCount;
        _barangayReports = barangayCount;
        _loading = false;
      });
    } catch (e) {
      print("Error loading reports: $e");
      setState(() => _loading = false);
    }
  }

  Color _getHeatColor(int count, int maxCount) {
    if (maxCount == 0) return Colors.blue.withOpacity(0.3);
    
    final intensity = count / maxCount;
    
    if (intensity >= 0.7) {
      return Colors.red.withOpacity(0.7);
    } else if (intensity >= 0.4) {
      return Colors.orange.withOpacity(0.6);
    } else {
      return Colors.yellow.withOpacity(0.5);
    }
  }

  List<CircleMarker> _getHeatmapCircles() {
    if (_reports.isEmpty) return [];

    // Group reports by proximity (within 100 meters)
    Map<String, List<Map<String, dynamic>>> clusters = {};
    
    for (var report in _reports) {
      final lat = report['latitude'];
      final lng = report['longitude'];
      final key = '${(lat * 100).round()}_${(lng * 100).round()}';
      
      if (!clusters.containsKey(key)) {
        clusters[key] = [];
      }
      clusters[key]!.add(report);
    }

    final maxCount = clusters.values.map((e) => e.length).reduce((a, b) => a > b ? a : b);

    return clusters.entries.map((entry) {
      final reports = entry.value;
      final avgLat = reports.map((r) => r['latitude'] as double).reduce((a, b) => a + b) / reports.length;
      final avgLng = reports.map((r) => r['longitude'] as double).reduce((a, b) => a + b) / reports.length;
      final count = reports.length;

      return CircleMarker(
        point: LatLng(avgLat, avgLng),
        color: _getHeatColor(count, maxCount),
        borderColor: Colors.red.withOpacity(0.3),
        borderStrokeWidth: 2,
        radius: 30 + (count * 5).toDouble(),
        useRadiusInMeter: true,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentData = _groupBy == 'city' ? _cityReports : _barangayReports;
    final sortedEntries = currentData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Report Heatmap',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1025A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Map View
                Expanded(
                  flex: 3,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _reports.isNotEmpty
                          ? LatLng(_reports[0]['latitude'], _reports[0]['longitude'])
                          : LatLng(14.5995, 120.9842),
                      initialZoom: 12,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      CircleLayer(
                        circles: _getHeatmapCircles(),
                      ),
                    ],
                  ),
                ),

                // Legend
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Heat Intensity',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLegendItem('Low', Colors.yellow),
                          _buildLegendItem('Medium', Colors.orange),
                          _buildLegendItem('High', Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),

                // Statistics
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.grey[100],
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Top Locations',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'city',
                                    label: Text('City'),
                                  ),
                                  ButtonSegment(
                                    value: 'barangay',
                                    label: Text('Barangay'),
                                  ),
                                ],
                                selected: {_groupBy},
                                onSelectionChanged: (Set<String> selected) {
                                  setState(() {
                                    _groupBy = selected.first;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: sortedEntries.length,
                            itemBuilder: (context, index) {
                              final entry = sortedEntries[index];
                              final maxCount = sortedEntries.first.value;
                              final percentage = (entry.value / maxCount * 100).round();

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getHeatColor(entry.value, maxCount),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: LinearProgressIndicator(
                                    value: entry.value / maxCount,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation(
                                      _getHeatColor(entry.value, maxCount),
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${entry.value}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '$percentage%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
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
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withOpacity(0.6),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}