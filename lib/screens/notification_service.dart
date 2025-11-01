import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send notification when report status changes
  static Future<void> sendStatusChangeNotification({
    required String userId,
    required String reportId,
    required String reportTitle,
    required String newStatus,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'status_change',
        'title': 'Report Status Updated',
        'message': 'Your report "$reportTitle" has been marked as $newStatus',
        'reportId': reportId,
        'read': false,
        'timestamp': Timestamp.now(), // ✅ Changed
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Send notification when someone comments on user's report
  static Future<void> sendCommentNotification({
    required String userId,
    required String reportId,
    required String reportTitle,
    required String commenterName,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'comment',
        'title': 'New Comment',
        'message': '$commenterName commented on your report "$reportTitle"',
        'reportId': reportId,
        'read': false,
        'timestamp': Timestamp.now(), // ✅ Changed from FieldValue.serverTimestamp()
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Send notification when someone upvotes user's report
  static Future<void> sendUpvoteNotification({
    required String userId,
    required String reportId,
    required String reportTitle,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'upvote',
        'title': 'Report Upvoted',
        'message': 'Someone upvoted your report "$reportTitle"',
        'reportId': reportId,
        'read': false,
        'timestamp': Timestamp.now(), // ✅ Changed from FieldValue.serverTimestamp()
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Send admin notification
  static Future<void> sendAdminNotification({
    required String userId,
    required String title,
    required String message,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'admin',
        'title': title,
        'message': message,
        'read': false,
        'timestamp': Timestamp.now(), // ✅ Changed from FieldValue.serverTimestamp()
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Get unread notification count
  static Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead(String userId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        await doc.reference.update({'read': true});
      }
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  // Delete old notifications (older than 30 days)
  static Future<void> cleanOldNotifications(String userId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      for (var doc in notifications.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error cleaning old notifications: $e');
    }
  }
}