import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUsersManagement extends StatefulWidget {
  const AdminUsersManagement({super.key});

  @override
  State<AdminUsersManagement> createState() => _AdminUsersManagementState();
}

class _AdminUsersManagementState extends State<AdminUsersManagement> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleBanUser(String userId, bool currentBanStatus, String username) async {
    final action = currentBanStatus ? 'unban' : 'ban';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action.toUpperCase()} User'),
        content: Text('Are you sure you want to $action $username?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: currentBanStatus ? Colors.green : Colors.red,
            ),
            child: Text(action.toUpperCase()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({'isBanned': !currentBanStatus}, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User ${currentBanStatus ? 'unbanned' : 'banned'} successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteUser(String userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete $username? This will delete all their reports and comments. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final userReports = await FirebaseFirestore.instance
            .collection('reports')
            .where('userId', isEqualTo: userId)
            .get();

        for (var report in userReports.docs) {
          final comments = await report.reference.collection('comments').get();
          for (var comment in comments.docs) {
            await comment.reference.delete();
          }
          await report.reference.delete();
        }

        final allReports = await FirebaseFirestore.instance
            .collection('reports')
            .get();

        for (var report in allReports.docs) {
          final userComments = await report.reference
              .collection('comments')
              .where('userId', isEqualTo: userId)
              .get();
          
          for (var comment in userComments.docs) {
            await comment.reference.delete();
          }
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting user: $e')),
          );
        }
      }
    }
  }

  Future<void> _viewUserReports(String userId, String username) async {
    final reports = await FirebaseFirestore.instance
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .get();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reports by $username',
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
                const SizedBox(height: 10),
                Expanded(
                  child: reports.docs.isEmpty
                      ? const Center(child: Text('No reports found'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: reports.docs.length,
                          itemBuilder: (context, index) {
                            final report = reports.docs[index];
                            final data = report.data();
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: data['imageUrl'] != null && data['imageUrl'].isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          data['imageUrl'],
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.report),
                                title: Text(data['title'] ?? 'Untitled'),
                                subtitle: Text(data['status'] ?? 'Pending'),
                              ),
                            );
                          },
                        ),
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
          'Manage Users',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1025A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
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
          
          // Users List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        const Text(
                          'Check Firestore security rules',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No users found. Users will appear here after they create an account.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                var users = snapshot.data!.docs;

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  users = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final username = (data['username'] ?? data['displayName'] ?? '').toString().toLowerCase();
                    final email = (data['email'] ?? '').toString().toLowerCase();
                    return username.contains(_searchQuery) || email.contains(_searchQuery);
                  }).toList();
                }

                if (users.isEmpty) {
                  return const Center(
                    child: Text('No matching users found'),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final data = user.data() as Map<String, dynamic>;
                    final userId = user.id;
                    final username = data['username'] ?? data['displayName'] ?? 'Unknown User';
                    final email = data['email'] ?? 'No email';
                    final isBanned = data['isBanned'] ?? false;
                    final isAdmin = data['isAdmin'] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isBanned
                              ? Colors.red
                              : isAdmin
                                  ? Colors.purple
                                  : const Color(0xFF1025A1),
                          child: Icon(
                            isAdmin ? Icons.admin_panel_settings : Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                username,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAdmin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (isBanned) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'BANNED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(email),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('View Reports'),
                              onTap: () {
                                Future.delayed(
                                  Duration.zero,
                                  () => _viewUserReports(userId, username),
                                );
                              },
                            ),
                            if (!isAdmin)
                              PopupMenuItem(
                                child: Text(isBanned ? 'Unban User' : 'Ban User'),
                                onTap: () {
                                  Future.delayed(
                                    Duration.zero,
                                    () => _toggleBanUser(userId, isBanned, username),
                                  );
                                },
                              ),
                            if (!isAdmin)
                              PopupMenuItem(
                                child: const Text(
                                  'Delete User',
                                  style: TextStyle(color: Colors.red),
                                ),
                                onTap: () {
                                  Future.delayed(
                                    Duration.zero,
                                    () => _deleteUser(userId, username),
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