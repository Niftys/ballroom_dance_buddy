import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static Future<String> addChoreography({
    required String name,
    required int styleId,
    required int danceId,
    required String level,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }

    DocumentReference docRef = await FirebaseFirestore.instance
        .collection('choreographies')
        .add({
      'uid': user.uid,  // Store under the logged-in user
      'name': name,
      'style_id': styleId,
      'dance_id': danceId,
      'level': level,
      'created_at': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  static Future<void> updateChoreography({
    required String choreoDocId,
    required String name,
    required int styleId,
    required int danceId,
    required String level,
  }) async {
    await FirebaseFirestore.instance.collection('choreographies').doc(choreoDocId).update({
      'name': name,
      'style_id': styleId,
      'dance_id': danceId,
      'level': level,
    });
  }

  static Future<void> deleteChoreography(String choreoDocId) async {
    await FirebaseFirestore.instance.collection('choreographies').doc(choreoDocId).delete();
  }

  // Add a figure to the "figures" array or a subcollection:
  static Future<void> addFigureToChoreography({
    required String choreoDocId,
    required Map<String, dynamic> figureData,
  }) async {
    // Approach A: store figures as an array
    await FirebaseFirestore.instance.collection('choreographies').doc(choreoDocId).update({
      'figures': FieldValue.arrayUnion([figureData]),
    });
    // or Approach B: subcollection
    // await FirebaseFirestore.instance
    //   .collection('choreographies')
    //   .doc(choreoDocId)
    //   .collection('figures')
    //   .add(figureData);
  }

  /// Listen to current user's choreographies
  static Stream<List<Map<String, dynamic>>> listenToChoreographies() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('choreographies')
        .where('uid', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // So we have easy reference to the Firestore doc id
        return data;
      }).toList();
    });
  }
}
