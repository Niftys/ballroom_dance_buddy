import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'database_service.dart';

class FirestoreService {

  static CollectionReference<Map<String, dynamic>> getUserChoreosRef() {
    final user = FirebaseAuth.instance.currentUser!;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('choreographies');
  }

  static Future<String> addChoreography({
    required String name,
    required int styleId,
    required int danceId,
    required String level,
    bool isPublic = false, // ✅ Toggle for public/private
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");
      final userId = user.uid;

      // ✅ Save under the user's private choreographies
      final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
      final docRef = await userDoc.collection('choreographies').add({
        'name': name,
        'style_id': styleId,
        'dance_id': danceId,
        'level': level,
        'created_by': userId,
        'created_at': FieldValue.serverTimestamp(),
        'isPublic': isPublic,
      });

      // ✅ Save in global collection if it's public
      if (isPublic) {
        await FirebaseFirestore.instance.collection('choreographies').doc(docRef.id).set({
          'name': name,
          'style_id': styleId,
          'dance_id': danceId,
          'level': level,
          'created_by': userId,
          'created_at': FieldValue.serverTimestamp(),
          'isPublic': true, // ✅ Ensure it is public
        });
      }

      return docRef.id;
    } catch (e) {
      print("Failed to save: $e");
      throw Exception("Save failed: $e");
    }
  }

  static Future<void> updateChoreography({
    required String userId,
    required String choreoDocId,
    required String name,
    required int styleId,
    required int danceId,
    required String level,
  }) async {
    final userChoreoRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoDocId);

    // Check if the choreography is public
    final docSnapshot = await userChoreoRef.get();
    final bool isPublic = docSnapshot.data()?['isPublic'] ?? false;

    // Update user's choreography
    await userChoreoRef.update({
      'name': name,
      'style_id': styleId,
      'dance_id': danceId,
      'level': level,
    });

    // If public, update the global choreography
    if (isPublic) {
      await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(choreoDocId)
          .update({
        'name': name,
        'style_id': styleId,
        'dance_id': danceId,
        'level': level,
      });
    }
  }

  static Future<void> updateChoreographyPrivacy({
    required String userId,
    required String choreoDocId,
    required bool isPublic,
  }) async {
    final userChoreoRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoDocId);

    // Update privacy flag
    await userChoreoRef.update({'isPublic': isPublic});

    if (isPublic) {
      // Copy choreography data to public collection
      final doc = await userChoreoRef.get();
      if (doc.exists) {
        // Copy main document
        await FirebaseFirestore.instance
            .collection('choreographies')
            .doc(choreoDocId)
            .set(doc.data()!);

        // Copy all figures to public collection
        final figuresSnapshot = await userChoreoRef.collection('figures').get();
        for (final figureDoc in figuresSnapshot.docs) {
          await FirebaseFirestore.instance
              .collection('choreographies')
              .doc(choreoDocId)
              .collection('figures')
              .doc(figureDoc.id)
              .set(figureDoc.data());
        }
      }
    } else {
      // Remove from public collection
      await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(choreoDocId)
          .delete();

      // Delete all figures from public collection
      final figuresSnapshot = await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(choreoDocId)
          .collection('figures')
          .get();

      for (final doc in figuresSnapshot.docs) {
        await doc.reference.delete();
      }
    }
  }

  static Future<void> deleteChoreography(String userId, String choreoDocId) async {
    final userChoreoRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoDocId);

    // Delete all figures in user's collection
    final figuresSnapshot = await userChoreoRef.collection('figures').get();
    for (final doc in figuresSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete from user's collection
    await userChoreoRef.delete();

    // Delete from global collection if public
    final publicChoreoRef = FirebaseFirestore.instance
        .collection('choreographies')
        .doc(choreoDocId);

    final publicDoc = await publicChoreoRef.get();
    if (publicDoc.exists) {
      // Delete all figures in public collection
      final publicFigures = await publicChoreoRef.collection('figures').get();
      for (final doc in publicFigures.docs) {
        await doc.reference.delete();
      }

      // Delete public choreography
      await publicChoreoRef.delete();
    }
  }

  // Add a figure to the "figures" subcollection:
  static Future<void> addFigureToChoreography({
    required String userId,
    required String choreoId,
    required Map<String, dynamic> figureData,
  }) async {
    // Add to user's collection
    final userFigureRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .collection('figures')
        .add(figureData);

    // Check if choreography is public
    final choreoDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .get();

    if (choreoDoc.exists && choreoDoc.data()?['isPublic'] == true) {
      // Add to global collection with the same ID
      await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(choreoId)
          .collection('figures')
          .doc(userFigureRef.id)
          .set(figureData);
    }
  }

  static Future<void> deleteFigureFromChoreography({
    required String userId,
    required String choreoId,
    required String figureId,
  }) async {
    // Delete from user's collection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .collection('figures')
        .doc(figureId)
        .delete();

    // Check if choreography is public
    final choreoDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .get();

    if (choreoDoc.exists && choreoDoc.data()?['isPublic'] == true) {
      // Delete from global collection
      await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(choreoId)
          .collection('figures')
          .doc(figureId)
          .delete();
    }
  }

  static Future<void> reorderFigures({
    required String userId,
    required String choreoId,
    required String figureId,
    required int newPosition,
  }) async {
    // Update user's collection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .collection('figures')
        .doc(figureId)
        .update({'position': newPosition});

    // Check if choreography is public
    final choreoDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .get();

    if (choreoDoc.exists && choreoDoc.data()?['isPublic'] == true) {
      // Update global collection
      await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(choreoId)
          .collection('figures')
          .doc(figureId)
          .update({'position': newPosition});
    }
  }

  static Future<void> updateFigureNotes({
    required String userId,
    required String choreoId,
    required String figureId,
    required String newNotes,
  }) async {
    // Update user's collection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .collection('figures')
        .doc(figureId)
        .update({'notes': newNotes});

    // Check if choreography is public
    final choreoDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .get();

    if (choreoDoc.exists && choreoDoc.data()?['isPublic'] == true) {
      // Update global collection
      await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(choreoId)
          .collection('figures')
          .doc(figureId)
          .update({'notes': newNotes});
    }
  }

  static Future<int?> getStyleIdByName(String styleName) async {
    return await DatabaseService.getStyleIdByName(styleName);
  }

  static Future<int?> getDanceIdByNameAndStyle(String danceName, int styleId) async {
    return await DatabaseService.getDanceIdByNameAndStyle(danceName, styleId);
  }

  static Future<void> copyChoreography(String choreoId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final userId = user.uid;

    // ✅ Fetch from global /choreographies/
    final choreoDoc = await FirebaseFirestore.instance
        .collection('choreographies')
        .doc(choreoId)
        .get();

    if (!choreoDoc.exists) {
      print("❌ ERROR: Choreography not found or is private: $choreoId");
      throw Exception("Choreography not found or is private.");
    }

    // ✅ Cast data properly
    final Map<String, dynamic> choreoData = choreoDoc.data() as Map<String, dynamic>;

    print("✅ Fetched Choreography: ${choreoData['name']}");

    // ✅ Ensure the choreography is public
    if (choreoData['isPublic'] != true) {
      print("❌ ERROR: This choreography is not public and cannot be copied.");
      throw Exception("This choreography is not public and cannot be copied.");
    }

    // ✅ Prepare the new choreography data
    final newChoreoData = {
      'name': choreoData['name'],
      'style_id': choreoData['style_id'],
      'dance_id': choreoData['dance_id'],
      'level': choreoData['level'],
      'created_by': userId, // Assign new owner
      'created_at': FieldValue.serverTimestamp(),
      'isPublic': false, // Copied choreo is private by default
    };

    // ✅ Save a new copy under the new user's account
    final newChoreoRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .add({
      ...newChoreoData,
      'copied_from': choreoId // Add reference to original
    });

    print("✅ Choreography copied with ID: ${newChoreoRef.id}");

    // ✅ Copy figures from the original choreography
    final figuresSnapshot = await choreoDoc.reference.collection('figures').get();

    for (var figureDoc in figuresSnapshot.docs) {
      await newChoreoRef.collection('figures').add(figureDoc.data());
    }

    print("✅ Figures copied successfully!");
  }

  static Stream<List<Map<String, dynamic>>> listenToChoreographies() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('choreographies')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }
}
