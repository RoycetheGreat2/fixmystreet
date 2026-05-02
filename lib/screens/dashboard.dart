import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'report_submission_page.dart';
import 'map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_details.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_dashboard.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'notification_service.dart';
import 'my_reports_screen.dart';

class DashBoard extends StatefulWidget {
  const DashBoard({super.key});

  @override
  State<DashBoard> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  final ImagePicker _picker = ImagePicker();
  bool _isAdmin = false;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _listenToNotifications();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() {
          _isAdmin = doc.data()?['isAdmin'] == true;
        });
      }
    } catch (e) {
      print("Error checking admin status: $e");
    }
  }

  void _listenToNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    NotificationService.getUnreadCount(user.uid).listen((count) {
      if (mounted) {
        setState(() {
          _unreadNotifications = count;
        });
      }
    });
  }

  Future<void> _openCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubmitReportScreen(imagePath: image.path),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'FixMyStreet',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 25,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1025A1),
        actions: [
          // Notification bell with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsPage(),
                    ),
                  );
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminDashboard(),
                  ),
                );
              },
              tooltip: 'Admin Panel',
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('❌ Error: ${snapshot.error}');
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            print('❌ No data');
            return const Center(child: Text('No data'));
          }

          print('📊 Total reports: ${snapshot.data!.docs.length}');

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No recent posts found.'),
            );
          }

          // ✅ Sort reports by timestamp in Flutter code
          final reports = snapshot.data!.docs.toList();
          
          // Try-catch around sorting in case of any issues
          try {
            reports.sort((a, b) {
              try {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTimestamp = aData['timestamp'];
                final bTimestamp = bData['timestamp'];
                
                // Handle null timestamps
                if (aTimestamp == null && bTimestamp == null) return 0;
                if (aTimestamp == null) return -1;
                if (bTimestamp == null) return 1;
                
                // Handle both Timestamp and serverTimestamp
                if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
                  return bTimestamp.compareTo(aTimestamp);
                }
                
                return 0;
              } catch (e) {
                print('Sort error: $e');
                return 0;
              }
            });
          } catch (e) {
            print('❌ Sorting failed: $e');
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final doc = reports[index];
              final data = doc.data() as Map<String, dynamic>;

              final username = data['username'] ?? 'Anonymous';
              final title = data['title']?.toString() ?? 'Untitled';
              final description = data['description']?.toString() ?? 'No description';
              final imageUrl = data['imageUrl']?.toString() ?? '';
              final landmark = data['landmark'] ?? 'No landmark provided';
              final timestamp = data['timestamp'] != null
                  ? (data['timestamp'] as Timestamp).toDate()
                  : DateTime.now();

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportDetailsScreen(reportData: doc),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(12)),
                          child: Image.network(
                            imageUrl,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'By $username',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              description,
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Color(0xFF1025A1), size: 18),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    landmark,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Posted on: ${timestamp.toLocal().toString().split(".")[0]}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF1025A1),
        child: Container(
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () {},
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.home, color: Color(0xFFA5E2FF)),
                    const SizedBox(height: 4),
                    Text(
                      'Home',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFA5E2FF),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _openCamera,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.camera_alt, color: Color(0xFFA5E2FF)),
                    const SizedBox(height: 4),
                    Text(
                      'Report',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFA5E2FF),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MapScreen()),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Icon(Icons.map, color: Color(0xFFA5E2FF)),
                    SizedBox(height: 4),
                    Text(
                      'Map',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA5E2FF),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyReportsScreen(),
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Icon(Icons.history, color: Color(0xFFA5E2FF)),
                    SizedBox(height: 4),
                    Text(
                      'My Reports',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA5E2FF),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfilePage()),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Icon(Icons.person, color: Color(0xFFA5E2FF)),
                    SizedBox(height: 4),
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA5E2FF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}