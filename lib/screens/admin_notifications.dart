import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class AdminSendNotificationPage extends StatefulWidget {
  const AdminSendNotificationPage({super.key});

  @override
  State<AdminSendNotificationPage> createState() => _AdminSendNotificationPageState();
}

class _AdminSendNotificationPageState extends State<AdminSendNotificationPage> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedRecipient = 'all'; // 'all' or 'specific'
  String? _selectedUserId;
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (_selectedRecipient == 'specific' && _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      if (_selectedRecipient == 'all') {
        // Send to all users
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .get();

        for (var userDoc in usersSnapshot.docs) {
          await NotificationService.sendAdminNotification(
            userId: userDoc.id,
            title: _titleController.text.trim(),
            message: _messageController.text.trim(),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Notification sent to ${usersSnapshot.docs.length} users')),
          );
        }
      } else {
        // Send to specific user
        await NotificationService.sendAdminNotification(
          userId: _selectedUserId!,
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification sent successfully')),
          );
        }
      }

      // Clear form
      _titleController.clear();
      _messageController.clear();
      setState(() {
        _selectedUserId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending notification: $e')),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Send Admin Notification',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1025A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send To',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('All Users'),
                    value: 'all',
                    groupValue: _selectedRecipient,
                    onChanged: (value) {
                      setState(() {
                        _selectedRecipient = value!;
                        _selectedUserId = null;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Specific User'),
                    value: 'specific',
                    groupValue: _selectedRecipient,
                    onChanged: (value) {
                      setState(() {
                        _selectedRecipient = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            
            if (_selectedRecipient == 'specific') ...[
              const SizedBox(height: 16),
              Text(
                'Select User',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data!.docs;

                  return Card(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButton<String>(
                        value: _selectedUserId,
                        hint: const Text('Choose a user'),
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: users.map((user) {
                          final userData = user.data() as Map<String, dynamic>;
                          final username = userData['username'] ?? userData['email'] ?? 'Unknown';
                          return DropdownMenuItem<String>(
                            value: user.id,
                            child: Text(username),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedUserId = value;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 24),
            Text(
              'Notification Title',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Enter notification title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Message',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter your message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendNotification,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _isSending ? 'Sending...' : 'Send Notification',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1025A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ========================================
// ADD THIS TO YOUR ADMIN DASHBOARD
// ========================================

// In your AdminDashboard widget, add a button to navigate to this page:
/*

// Add this import at the top:
import 'admin_send_notification.dart';

// Add this somewhere in your admin dashboard UI:
ElevatedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminSendNotificationPage(),
      ),
    );
  },
  icon: const Icon(Icons.notifications_active),
  label: const Text('Send Notification'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.red,
    foregroundColor: Colors.white,
  ),
),

*/