import 'package:flutter/material.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'report_submitted_screen.dart'; // ✅ ADD THIS IMPORT

class SubmitReportScreen extends StatefulWidget {
  final String imagePath;
  const SubmitReportScreen({super.key, required this.imagePath});

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  bool _loading = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied")),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      print("Location error: $e");
    }
  }

  Future<void> _submitReport() async {
    if (_titleController.text.isEmpty ||
        _descController.text.isEmpty ||
        _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill out all fields")),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to detect location.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final collectionRef = FirebaseFirestore.instance.collection('reports');

      // ✅ Create GeoFirePoint for current location
      final currentPoint = GeoFirePoint(GeoPoint(_latitude!, _longitude!));

      // ✅ Query nearby reports (within 50 meters) and check for duplicates
      print("Checking for duplicates at: $_latitude, $_longitude");
      print("Looking for title: ${_titleController.text.trim().toLowerCase()}");
      
      final nearbyReports = <DocumentSnapshot>[];
      
      try {
        final geoQuery = GeoCollectionReference(collectionRef)
            .subscribeWithin(
              center: currentPoint,
              radiusInKm: 0.05, // 50 meters
              field: 'position',
              geopointFrom: (data) {
                final position = data['position'] as Map<String, dynamic>;
                return position['geopoint'] as GeoPoint;
              },
              strictMode: true,
            );

        // Wait for the first emission with a timeout
        await geoQuery.first.timeout(
          const Duration(seconds: 10),
          onTimeout: () => [],
        ).then((docs) {
          nearbyReports.addAll(docs);
        });

        print("Found ${nearbyReports.length} nearby reports");

        // Check for duplicates based on title and status
        for (var doc in nearbyReports) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            print("Nearby report: ${data['title']} (Status: ${data['status']})");
          }
        }

        final isDuplicate = nearbyReports.any((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          
          final isSameTitle = data['title'].toString().toLowerCase().trim() ==
              _titleController.text.trim().toLowerCase();
          final isNotResolved = data['status'] != 'Resolved';
          
          return isSameTitle && isNotResolved;
        });

        if (isDuplicate) {
          print("Duplicate detected! Blocking submission.");
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Duplicate Report Detected"),
              content: const Text(
                  "A similar report already exists near this location (within 50m)."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          setState(() => _loading = false);
          return;
        }
        
        print("No duplicates found, proceeding with submission.");
      } catch (e) {
        print("Error checking for duplicates: $e");
        // Continue with submission if geo query fails
      }

      // ✅ Upload image to Cloudinary
      final file = File(widget.imagePath);
      const cloudName = 'duovfomys';
      const uploadPreset = 'unsigned_preset';

      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = json.decode(responseData);
        final imageUrl = data['secure_url'];

        final user = FirebaseAuth.instance.currentUser;

        // ✅ FIXED: Save the document reference so we can get the ID
        final reportDoc = await collectionRef.add({
          'userId': user?.uid,
          'username': user?.displayName ?? 'Anonymous',
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'landmark': _locationController.text.trim(),
          'latitude': _latitude,
          'longitude': _longitude,
          'position': currentPoint.data,
          'imageUrl': imageUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'commentCount': 0,
          'status': 'Pending',
          'upvotes': 0,
          'upvoters': [],
        });

        // ✅ FIXED: Navigate to success screen instead of just popping
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ReportSubmittedScreen(
                reportId: reportDoc.id,
                status: 'Pending',
                expectedResponse: '3-5 business days',
              ),
            ),
          );
        }
      } else {
        print("Cloudinary upload failed: ${response.statusCode}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Image upload failed.")),
          );
        }
      }
    } catch (e) {
      print("Error uploading report: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        foregroundColor: const Color(0xFFA5E2FF),
        title: Text(
          'Report Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1025A1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.fill,
                  height: 200,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF1025A1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _latitude != null
                          ? "Detected: $_latitude, $_longitude"
                          : "Detecting location...",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Landmark or Location',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1025A1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _loading ? null : _submitReport,
                child: Text(
                  _loading ? "Submitting..." : "Submit Report",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}