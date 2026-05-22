import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'report_details.dart';
import 'heatmap_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/map_tiles.dart';

class MapScreen extends StatefulWidget {
  final bool embedded;

  const MapScreen({super.key, this.embedded = false});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _userLocation;
  List<Map<String, dynamic>> _reports = [];
  Map<String, dynamic>? _selectedReport;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _fetchReports();
  }

  Future<void> _getUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print("Error getting user location: $e");
    }
  }

  Future<void> _fetchReports() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .get();

      final reports = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'status': data['status'] ?? 'Pending',
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'imageUrl': data['imageUrl'] ?? '',
          'upvotes': data['upvotes'] ?? 0,
          'timestamp': data['timestamp'],
        };
      }).where((report) {
        return report['latitude'] != null && report['longitude'] != null;
      }).toList();

      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      print("Error fetching reports: $e");
      setState(() => _loading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in-progress':
      case 'in progress':
        return Colors.lightBlue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  // Group reports that are very close together (within ~10 meters)
  List<Map<String, dynamic>> _groupNearbyReports() {
    final grouped = <Map<String, dynamic>>[];
    final processed = <int>{};

    for (int i = 0; i < _reports.length; i++) {
      if (processed.contains(i)) continue;

      final report = _reports[i];
      final cluster = [report];
      processed.add(i);

      // Find nearby reports
      for (int j = i + 1; j < _reports.length; j++) {
        if (processed.contains(j)) continue;

        final other = _reports[j];
        final distance = Geolocator.distanceBetween(
          report['latitude'],
          report['longitude'],
          other['latitude'],
          other['longitude'],
        );

        if (distance < 10) {
          // Within 10 meters
          cluster.add(other);
          processed.add(j);
        }
      }

      // Create a grouped marker
      if (cluster.length > 1) {
        grouped.add({
          'isCluster': true,
          'count': cluster.length,
          'reports': cluster,
          'latitude': report['latitude'],
          'longitude': report['longitude'],
          'status': report['status'], // Use first report's status for color
        });
      } else {
        grouped.add({
          'isCluster': false,
          ...report,
        });
      }
    }

    return grouped;
  }

  void _showReportPreview(Map<String, dynamic> reportData) {
    setState(() {
      _selectedReport = reportData;
    });
  }

  Future<void> _navigateToReportDetails(String reportId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .get();
      
      if (doc.exists && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportDetailsScreen(reportData: doc),
          ),
        );
      }
    } catch (e) {
      print("Error navigating to report: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final groupedReports = _groupNearbyReports();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        backgroundColor: const Color(0xFF1025A1),
        title: Text(
          'Map View',
          style: GoogleFonts.poppins(
            color: Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color.fromARGB(255, 255, 255, 255),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.whatshot, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HeatmapScreen()),
              );
            },
            tooltip: 'View Heatmap',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Map Container
              Container(
                width: screenWidth,
                height: screenHeight * 0.65,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: _userLocation ?? LatLng(14.5995, 120.9842), // Manila default
                          initialZoom: 13,
                          onTap: (_, __) {
                            setState(() {
                              _selectedReport = null;
                            });
                          },
                        ),
                        children: [
                          AppMapTiles.layer(),
                          AppMapTiles.attribution(),
                          MarkerLayer(
                            markers: [
                              // User location marker
                              if (_userLocation != null)
                                Marker(
                                  point: _userLocation!,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.blue,
                                    size: 30,
                                  ),
                                ),
                              // Report markers
                              ...groupedReports.map((item) {
                                final isCluster = item['isCluster'] == true;
                                final point = LatLng(
                                  item['latitude'],
                                  item['longitude'],
                                );

                                return Marker(
                                  point: point,
                                  width: isCluster ? 50 : 40,
                                  height: isCluster ? 50 : 40,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (isCluster) {
                                        // Show cluster reports
                                        _showClusterDialog(item['reports']);
                                      } else {
                                        _showReportPreview(item);
                                      }
                                    },
                                    child: isCluster
                                        ? _buildClusterMarker(
                                            item['count'],
                                            _getStatusColor(item['status']),
                                          )
                                        : _buildSingleMarker(
                                            _getStatusColor(item['status']),
                                          ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ],
                      ),
              ),

              // Legend
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Container(
                      width: screenWidth * 0.9,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Legend',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF1025A1),
                            ),
                          ),
                          const SizedBox(height: 8),
                          legendItem(Colors.orange, 'Pending Report'),
                          const SizedBox(height: 5),
                          legendItem(Colors.lightBlue, 'In-Progress'),
                          const SizedBox(height: 5),
                          legendItem(Colors.green, 'Resolved'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Report Preview Card (appears above map)
          if (_selectedReport != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: () => _navigateToReportDetails(_selectedReport!['id']),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Image
                      if (_selectedReport!['imageUrl'] != null &&
                          _selectedReport!['imageUrl'].isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _selectedReport!['imageUrl'],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                      const SizedBox(width: 15),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedReport!['title'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                        _selectedReport!['status']),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _selectedReport!['status'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _selectedReport!['description'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(Icons.thumb_up,
                                    size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 5),
                                Text(
                                  '${_selectedReport!['upvotes']} upvotes',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleMarker(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildClusterMarker(int count, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _showClusterDialog(List<dynamic> reports) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${reports.length} Reports at this location'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(report['status']),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(report['title']),
                subtitle: Text(report['status']),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToReportDetails(report['id']);
                },
              );
            },
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

  Widget legendItem(Color color, String label) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}