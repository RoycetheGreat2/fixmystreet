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
  final _userSearchController = TextEditingController();
  String _selectedRecipient = 'all';
  String? _selectedUserId;
  String? _selectedUsername;
  bool _isSending = false;
  bool _showUserDropdown = false;
  String _userSearchQuery = '';

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _userSearchController.dispose();
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

      _titleController.clear();
      _messageController.clear();
      _userSearchController.clear();
      setState(() {
        _selectedUserId = null;
        _selectedUsername = null;
        _userSearchQuery = '';
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
                        _selectedUsername = null;
                        _showUserDropdown = false;
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
              
              // Searchable User Selector
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var users = snapshot.data!.docs;
                  
                  // Filter users based on search
                  if (_userSearchQuery.isNotEmpty) {
                    users = users.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final username = (data['username'] ?? data['email'] ?? '').toString().toLowerCase();
                      return username.contains(_userSearchQuery.toLowerCase());
                    }).toList();
                  }

                  return Column(
                    children: [
                      // Search TextField
                      TextField(
                        controller: _userSearchController,
                        decoration: InputDecoration(
                          hintText: _selectedUsername ?? 'Search and select a user...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _selectedUsername != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _selectedUserId = null;
                                      _selectedUsername = null;
                                      _userSearchController.clear();
                                      _userSearchQuery = '';
                                      _showUserDropdown = false;
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
                        onTap: () {
                          setState(() {
                            _showUserDropdown = true;
                          });
                        },
                        onChanged: (value) {
                          setState(() {
                            _userSearchQuery = value;
                            _showUserDropdown = true;
                          });
                        },
                      ),
                      
                      // Dropdown List
                      if (_showUserDropdown && users.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final userData = user.data() as Map<String, dynamic>;
                              final username = userData['username'] ?? userData['email'] ?? 'Unknown';
                              final email = userData['email'] ?? '';
                              
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF1025A1),
                                  child: Text(
                                    username[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(username),
                                subtitle: email.isNotEmpty ? Text(email) : null,
                                onTap: () {
                                  setState(() {
                                    _selectedUserId = user.id;
                                    _selectedUsername = username;
                                    _userSearchController.text = username;
                                    _showUserDropdown = false;
                                    _userSearchQuery = '';
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      
                      if (_showUserDropdown && users.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Text(
                            'No users found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                    ],
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