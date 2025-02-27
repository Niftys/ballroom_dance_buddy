import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class FirestoreService {

  static Future<void> importFiguresFromJson(String filePath) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      final existingFigures = await firestore.collection("figures").get();
      if (existingFigures.docs.isNotEmpty) {
        print("Figures already exist. Skipping import.");
        return;
      }

      String jsonString = await rootBundle.loadString(filePath);
      List<dynamic> figuresData = json.decode(jsonString);

      for (var styleData in figuresData) {
        String style = styleData["style"];

        for (var danceData in styleData["dances"]) {
          String dance = danceData["name"];

          danceData["levels"].forEach((level, figures) async {
            for (var figure in figures) {
              await firestore.collection("figures").add({
                "style": style,
                "dance": dance,
                "level": level,
                "description": figure["description"],
                "video_url": figure["video_url"] ?? "",
                "start": figure["start"] ?? 0,
                "end": figure["end"] ?? 0,
              });
            }
          });
        }
      }

      print("Figures successfully imported to Firestore!");
    } catch (e) {
      print("Error importing figures: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getAllStyles() async {
    try {
      final QuerySnapshot figuresSnapshot =
      await FirebaseFirestore.instance.collection("figures").get();

      final Set<String> uniqueStyles = figuresSnapshot.docs
          .map((doc) => doc.get('style') as String)
          .toSet();

      return uniqueStyles.toList().asMap().entries.map((entry) {
        return {
          "id": entry.key + 1,
          "name": entry.value
        };
      }).toList();
    } catch (e) {
      print("Error fetching styles: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getDancesByStyleName(String styleName) async {
    try {
      final QuerySnapshot figuresSnapshot = await FirebaseFirestore.instance
          .collection("figures")
          .where("style", isEqualTo: styleName)
          .get();

      final Set<String> uniqueDances = figuresSnapshot.docs
          .map((doc) => doc.get('dance') as String)
          .toSet();

      return uniqueDances.toList().asMap().entries.map((entry) {
        return {
          "id": entry.key + 1,
          "name": entry.value
        };
      }).toList();
    } catch (e) {
      print("Error fetching dances: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getFiguresForChoreography({
    required String choreoId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final userId = user.uid;

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(choreoId)
          .collection('figures')
          .orderBy('position')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print("Error fetching figures for choreography: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllDances() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection("dances").get();
      return snapshot.docs.map((doc) => {"id": doc.id, "name": doc["name"]}).toList();
    } catch (e) {
      print("Error fetching dances: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllFigures() async {
    try {
      print("Fetching all figures from Firestore...");

      final QuerySnapshot globalSnapshot = await FirebaseFirestore.instance
          .collection("figures")
          .get();

      List<QueryDocumentSnapshot> customFigures = [];

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final QuerySnapshot customSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('custom_figures')
            .get();

        customFigures = customSnapshot.docs;
      }

      final allFigures = [
        ...globalSnapshot.docs,
        ...customFigures,
      ];

      if (allFigures.isEmpty) {
        print("⚠No figures found in Firestore.");
        return [];
      }

      return allFigures.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'style': data.containsKey('style') ? data['style'] : 'Custom',
          'dance': data.containsKey('dance') ? data['dance'] : 'Custom',
          'level': data.containsKey('level') ? data['level'] : 'Custom',
          'description': data['description'] ?? 'No Description',
          'video_url': data['video_url'] ?? '',
          'start': data['start'] ?? 0,
          'end': data['end'] ?? 0,
          'isCustom': customFigures.any((custDoc) => custDoc.id == doc.id) ||
              data['isCustom'] == true,
        };
      }).toList();
    } catch (e) {
      print("Error fetching all figures: $e");
      return [];
    }
  }

  static CollectionReference<Map<String, dynamic>> getUserChoreosRef() {
    final user = FirebaseAuth.instance.currentUser!;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('choreographies');
  }

  static Future<void> addCustomFigure({
    required String description,
    required String styleName,
    required String danceName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('custom_figures')
          .add({
        'description': description,
        'style': styleName,
        'dance': danceName,
        'level': 'Custom',
        'created_at': FieldValue.serverTimestamp(),
      });

      print("Custom figure added for user: $description");
    } catch (e) {
      print("Error adding custom figure: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getUserCustomFigures({
    required String styleName,
    required String danceName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final userId = user.uid;

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('custom_figures')
          .where('style', isEqualTo: styleName)
          .where('dance', isEqualTo: danceName)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print("Error fetching user's custom figures: $e");
      return [];
    }
  }

  static Future<void> addCustomFigureToChoreography({
    required String choreoId,
    required String description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;

    try {
      final nextPosition = await _getNextFigurePosition(userId, choreoId);

      final figureData = {
        'description': description,
        'level': 'Custom',
        'created_at': FieldValue.serverTimestamp(),
        'position': nextPosition,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(choreoId)
          .collection('figures')
          .add(figureData);

      print("Figure added to choreography: $description");
    } catch (e) {
      print("Error adding figure: $e");
    }
  }

  static Future<void> deleteCustomFigureFromChoreography({
    required String choreoId,
    required String figureId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(choreoId)
          .collection('figures')
          .doc(figureId)
          .delete();

      print("Custom figure deleted successfully.");
    } catch (e) {
      print("Error deleting custom figure: $e");
    }
  }

  static Future<void> deleteCustomFigure({
    required String figureId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('custom_figures')
          .doc(figureId)
          .delete();

      print("Custom figure deleted permanently");
    } catch (e) {
      print("Error deleting custom figure: $e");
      throw Exception("Failed to delete custom figure");
    }
  }

  static Future<int> _getNextFigurePosition(String userId, String choreoId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .collection('figures')
        .orderBy('position', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      return (snap.docs.first.data()['position'] ?? 0) + 1;
    }
    return 0;
  }

  static Future<String> addChoreography({
    required String name,
    required String styleName,
    required String danceName,
    required String level,
    bool isPublic = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final userId = user.uid;

    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .add({
      'name': name,
      'style_name': styleName,
      'dance_name': danceName,
      'level': level,
      'isPublic': isPublic,
      'created_by': userId,
      'created_at': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  static Future<void> updateChoreography({
    required String userId,
    required String choreoDocId,
    required String name,
    required String styleName,
    required String danceName,
    required String level,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(choreoDocId);

      await docRef.update({
        'name': name,
        'style_name': styleName,
        'dance_name': danceName,
        'level': level,
        'updated_at': FieldValue.serverTimestamp(),
      });

      print("Successfully updated choreography: $choreoDocId");
    } catch (e) {
      print("Error updating choreography: $e");
      throw Exception("Failed to update choreography: $e");
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

    await userChoreoRef.update({'isPublic': isPublic});

    if (isPublic) {
      final doc = await userChoreoRef.get();
      if (doc.exists) {
        await FirebaseFirestore.instance
            .collection('choreographies')
            .doc(choreoDocId)
            .set(doc.data()!);

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
      await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(choreoDocId)
          .delete();

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

    final publicChoreoRef = FirebaseFirestore.instance
        .collection('choreographies')
        .doc(choreoDocId);

    try {
      final userChoreoDoc = await userChoreoRef.get();
      final bool wasPublic = userChoreoDoc.data()?['isPublic'] ?? false;

      final batch = FirebaseFirestore.instance.batch();

      final userFigures = await userChoreoRef.collection('figures').get();
      for (final doc in userFigures.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(userChoreoRef);

      if (wasPublic) {
        final publicDoc = await publicChoreoRef.get();
        if (publicDoc.exists) {
          final publicFigures = await publicChoreoRef.collection('figures').get();
          for (final doc in publicFigures.docs) {
            batch.delete(doc.reference);
          }
          batch.delete(publicChoreoRef);
        }
      }

      await batch.commit();
      print("Choreography deleted successfully");
    } catch (e) {
      print("Error deleting choreography: $e");
      throw Exception("Failed to delete choreography: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getFiguresByStyleAndDance(
      String styleName,
      String danceName
      ) async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('figures')
          .where('style', isEqualTo: styleName)
          .where('dance', isEqualTo: danceName)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error fetching figures by style and dance: $e');
      return [];
    }
  }

  static Future<void> addFigureToChoreography({
    required String userId,
    required String choreoId,
    required Map<String, dynamic> figureData,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .collection('figures');

    final nextPosition = await _getNextFigurePosition(userId, choreoId);

    final figureWithPosition = {
      ...figureData,
      'position': nextPosition,
    };

    await docRef.add(figureWithPosition);

    final choreoDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .get();

    if (choreoDoc.exists && choreoDoc.data()?['isPublic'] == true) {
      await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(choreoId)
          .collection('figures')
          .add(figureWithPosition);
    }

    print("Figure added successfully: ${figureWithPosition['description']}");
  }

  static Future<void> deleteFigureFromChoreography({
    required String userId,
    required String choreoId,
    required String figureId,
  }) async {
    final figureRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .collection('figures')
        .doc(figureId);

    try {
      print("Attempting to delete figure with ID: $figureId");

      final docSnapshot = await figureRef.get();
      if (!docSnapshot.exists) {
        print("Error: Figure with ID $figureId does not exist in choreography $choreoId");

        final query = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('choreographies')
            .doc(choreoId)
            .collection('figures')
            .where('copied_from', isEqualTo: figureId)
            .get();

        if (query.docs.isNotEmpty) {
          print("Found figure with copied_from ID: ${query.docs.first.id}");
          await query.docs.first.reference.delete();
          print("Figure deleted successfully using copied_from reference");
          return;
        }

        return;
      }

      final figureData = docSnapshot.data();
      print("Figure data before deletion: $figureData");

      await figureRef.delete();
      print("Figure deleted successfully: ${figureData?['description'] ?? 'Unknown'}");

      final choreoDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(choreoId)
          .get();

      if (choreoDoc.exists && choreoDoc.data()?['isPublic'] == true) {
        await FirebaseFirestore.instance
            .collection('choreographies')
            .doc(choreoId)
            .collection('figures')
            .doc(figureId)
            .delete();
        print("Also deleted figure from public choreography collection");
      }
    } catch (e) {
      print("Error deleting figure: $e");
    }
  }

  static Future<void> reorderFigures({
    required String userId,
    required String choreoId,
    required String figureId,
    required int newPosition,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .collection('figures')
        .doc(figureId)
        .update({'position': newPosition});

    final choreoDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .get();

    if (choreoDoc.exists && choreoDoc.data()?['isPublic'] == true) {
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
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .collection('figures')
        .doc(figureId)
        .update({'notes': newNotes});

    final choreoDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(choreoId)
        .get();

    if (choreoDoc.exists && choreoDoc.data()?['isPublic'] == true) {
      await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(choreoId)
          .collection('figures')
          .doc(figureId)
          .update({'notes': newNotes});
    }
  }

  static Future<void> copyChoreography(String choreoId, String userId) async {
    try {
      final choreoDoc = await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(choreoId)
          .get();

      if (!choreoDoc.exists) throw Exception("Choreography not found");
      final choreoData = choreoDoc.data()!;

      final bool isPublic = choreoData.containsKey('isPublic') && choreoData['isPublic'] == true;
      if (!isPublic) throw Exception("Choreography is not public");

      final newChoreoRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .add({
        ...choreoData,
        'created_by': userId,
        'isPublic': false,
        'copied_from': choreoId,
        'created_at': FieldValue.serverTimestamp(),
      });

      final figuresSnapshot = await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(choreoId)
          .collection('figures')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      final newFiguresRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(newChoreoRef.id)
          .collection('figures');

      final customFigureMap = <String, String>{};

      for (final figureDoc in figuresSnapshot.docs) {
        final figureData = figureDoc.data();

        final bool isCustomFigure = figureData.containsKey('isCustom') && figureData['isCustom'] == true;
        if (isCustomFigure) {
          final newCustomFigRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('custom_figures')
              .doc();

          customFigureMap[figureDoc.id] = newCustomFigRef.id;

          batch.set(newCustomFigRef, {
            ...figureData,
            'created_by': userId,
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        final newFigRef = newFiguresRef.doc();
        batch.set(newFigRef, {
          ...figureData,
          'original_figure_id': figureDoc.id,
          'custom_figure_id': isCustomFigure ? customFigureMap[figureDoc.id] : null,
          'isCustom': isCustomFigure,
          'copied_from': figureDoc.id,
        });
      }

      await batch.commit();
      print("Choreography copied with custom figures");
    } catch (e) {
      print("Error copying choreography: $e");
      rethrow;
    }
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
