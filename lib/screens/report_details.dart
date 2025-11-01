import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart'; // ✅ Import NotificationService

class ReportDetailsScreen extends StatefulWidget {
  final DocumentSnapshot reportData;
  const ReportDetailsScreen({super.key, required this.reportData});

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  final _commentController = TextEditingController();
  bool _upvoted = false;
  int _upvoteCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUpvoteStatus();
  }

  Future<void> _loadUpvoteStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final report = await FirebaseFirestore.instance
        .collection('reports')
        .doc(widget.reportData.id)
        .get();

    final List<dynamic> upvoters = List.from(report['upvoters'] ?? []);
    setState(() {
      _upvoted = upvoters.contains(currentUser.uid);
      _upvoteCount = upvoters.length;
    });
  }

  Future<void> _toggleUpvote() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final reportRef =
        FirebaseFirestore.instance.collection('reports').doc(widget.reportData.id);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportRef);
      final List<dynamic> upvoters = List.from(snapshot['upvoters'] ?? []);

      bool isUpvoted;
      if (upvoters.contains(currentUser.uid)) {
        upvoters.remove(currentUser.uid);
        isUpvoted = false;
      } else {
        upvoters.add(currentUser.uid);
        isUpvoted = true;
      }

      transaction.update(reportRef, {
        'upvoters': upvoters,
        'upvotes': upvoters.length,
      });

      // Update local state inside transaction to avoid inconsistencies
      setState(() {
        _upvoted = isUpvoted;
        _upvoteCount = upvoters.length;
      });
    });

    // ✅ Send upvote notification (only when upvoting, not when removing upvote)
    if (_upvoted) {
      final reportData = widget.reportData.data() as Map<String, dynamic>;
      final reportOwnerId = reportData['userId'];
      final reportTitle = reportData['title'] ?? 'Your report';
      
      // Don't notify yourself
      if (reportOwnerId != null && reportOwnerId != currentUser.uid) {
        await NotificationService.sendUpvoteNotification(
          userId: reportOwnerId,
          reportId: widget.reportData.id,
          reportTitle: reportTitle,
        );
      }
    }
  }

  Future<void> _postComment(String text) async {
    if (text.trim().isEmpty) return;

    final reportRef =
        FirebaseFirestore.instance.collection('reports').doc(widget.reportData.id);

    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUsername = currentUser?.displayName ?? 'Anonymous';

    await reportRef.collection('comments').add({
      'text': text.trim(),
      'username': currentUsername,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _commentController.clear();

    // ✅ Send comment notification
    final reportData = widget.reportData.data() as Map<String, dynamic>;
    final reportOwnerId = reportData['userId'];
    final reportTitle = reportData['title'] ?? 'Your report';
    
    // Don't notify yourself
    if (reportOwnerId != null && reportOwnerId != currentUser?.uid) {
      await NotificationService.sendCommentNotification(
        userId: reportOwnerId,
        reportId: widget.reportData.id,
        reportTitle: reportTitle,
        commenterName: currentUsername,
      );
    }
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(timestamp.toDate());
    if (diff.inDays > 0) return '${diff.inDays} day(s) ago';
    if (diff.inHours > 0) return '${diff.inHours} hour(s) ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minute(s) ago';
    return 'Just now';
  }

  void _showCommentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Write a comment...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blue),
              onPressed: () {
                _postComment(_commentController.text);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final data = widget.reportData;
    const double dividerWidthFactor = 0.9;

    return Scaffold(
      appBar: AppBar(
        title: Text('Report Details', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1025A1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF1025A1),
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['username'] ?? 'Anonymous', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                              Text(_timeAgo(data['timestamp']), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
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
                          child: Text(data['status'] ?? 'Pending', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['title'] ?? 'Untitled', style: GoogleFonts.inter(fontSize: 27, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        Text(data['description'] ?? 'No description', style: GoogleFonts.inter(fontSize: 16)),
                        const SizedBox(height: 14),
                        if ((data['landmark'] ?? '').isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 12, color: Colors.grey),
                              const SizedBox(width: 2),
                              Text(data['landmark'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if ((data['imageUrl'] ?? '').isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(0),
                      child: Image.network(data['imageUrl'] ?? '', width: double.infinity, height: 300, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 30),
                  Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * dividerWidthFactor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$_upvoteCount Upvotes', style: const TextStyle(fontWeight: FontWeight.w500)),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('reports')
                                .doc(widget.reportData.id)
                                .collection('comments')
                                .snapshots(),
                            builder: (context, snapshot) {
                              final commentCount = snapshot.data?.docs.length ?? 0;
                              return Text('$commentCount Comments', style: const TextStyle(fontWeight: FontWeight.w500));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(width: MediaQuery.of(context).size.width * dividerWidthFactor, height: 1, color: Colors.grey[300]),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(_upvoted ? Icons.favorite : Icons.favorite_border, color: _upvoted ? Colors.red : Colors.grey),
                        onPressed: _toggleUpvote,
                      ),
                      const SizedBox(width: 40),
                      IconButton(icon: const Icon(Icons.comment, color: Colors.grey), onPressed: _showCommentSheet),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Comments', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reports')
                        .doc(widget.reportData.id)
                        .collection('comments')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: const Text('No comments yet', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        );
                      }
                      final comments = snapshot.data!.docs;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: comments.map((doc) {
                          final commentData = doc.data() as Map<String, dynamic>? ?? {};
                          final username = commentData['username'] ?? 'Anonymous';
                          final text = commentData['text'] ?? '';
                          final timestamp = commentData['timestamp'] as Timestamp?;
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.grey[300],
                                      child: const Icon(Icons.person, color: Colors.white, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(_timeAgo(timestamp), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(text),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      backgroundColor: Colors.grey[200],
    );
  }
}