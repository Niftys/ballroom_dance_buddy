import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../login.dart';
import '../../services/firestore_service.dart';
import 'add_choreography_screen.dart';
import 'view_choreography_screen_firestore.dart';
import '/services/database_service.dart';

class NotesScreenFirestore extends StatefulWidget {
  final VoidCallback? onOpenSettings;
  const NotesScreenFirestore({Key? key, this.onOpenSettings}) : super(key: key);

  @override
  _NotesScreenFirestoreState createState() => _NotesScreenFirestoreState();
}

class _NotesScreenFirestoreState extends State<NotesScreenFirestore> {
  // If you want searching, you can keep a _searchController
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _isSearching = _searchQuery.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Stream all choreographies from Firestore for current user
  Stream<List<Map<String, dynamic>>> _choreosStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('choreographies')
        .snapshots()
        .asyncMap((snapshot) async {
      final choreos = await Future.wait(snapshot.docs.map((doc) async {
        try {
          final data = doc.data();
          data['id'] = doc.id;

          // Validate required fields
          final styleId = data['style_id'] as int? ?? 0;
          final danceId = data['dance_id'] as int? ?? 0;

          // Get names with fallbacks
          final styleName = await DatabaseService.getStyleNameById(styleId);
          final danceName = await DatabaseService.getDanceNameById(danceId);

          return {
            ...data,
            'style_name': styleName,
            'dance_name': danceName,
          };
        } catch (e) {
          print("Error processing choreo ${doc.id}: $e");
          return {
            ...doc.data(),
            'id': doc.id,
            'style_name': 'Error loading style',
            'dance_name': 'Error loading dance',
          };
        }
      }));

      return choreos.where((c) => c != null).toList();
    });
  }

  void _addChoreography() {
    // Navigate to your Firestore-based AddChoreographyScreen
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddChoreographyScreen(
        // no docId => new choreo
        onSave: (docId, styleId, danceId, level) {
          // after save
        },
      ),
    ));
  }

  void _viewChoreography(Map<String, dynamic> c) {
    final docId = c['id'] as String; // Firestore doc ID
    final styleId = c['style_id'] as int? ?? 0;
    final danceId = c['dance_id'] as int? ?? 0;
    final level = c['level'] as String? ?? 'Bronze';

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ViewChoreographyScreenFirestore(
        choreoDocId: docId,
        styleId: styleId,
        danceId: danceId,
        level: level,
      ),
    ));
  }

  void _editChoreography(Map<String, dynamic> c) {
    final docId   = c['id'] as String;
    final name    = c['name'] as String? ?? '';
    final styleId = c['style_id'] as int? ?? 0;
    final danceId = c['dance_id'] as int? ?? 0;
    final level   = c['level'] as String? ?? 'Bronze';

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddChoreographyScreen(
        docId: docId,
        initialName: name,
        initialStyleId: styleId,
        initialDanceId: danceId,
        initialLevel: level,
        onSave: (docId, styleId, danceId, level) {
          // do something after editing
        },
      ),
    ));
  }

  void _deleteChoreography(Map<String, dynamic> c) async {
    final docId = c['id'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Confirm Deletion"),
        content: Text("Are you sure you want to delete '${c['name']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: Theme.of(context).textTheme.titleSmall),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(docId)
          .delete();
    }
  }

  void _logout() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      if (user.isAnonymous) {
        try {
          // Delete user document and subcollections
          await _deleteUserData(user.uid);
          // Delete auth account
          await user.delete();
        } catch (e) {
          print("Error deleting guest account: $e");
        }
      }
      // Sign out regardless of account type
      await FirebaseAuth.instance.signOut();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  Future<void> _deleteUserData(String userId) async {
    try {
      final choreosSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .get();

      // ✅ Delete all figures inside choreographies
      for (final choreo in choreosSnapshot.docs) {
        final figuresSnapshot = await choreo.reference.collection('figures').get();
        for (final figure in figuresSnapshot.docs) {
          await figure.reference.delete();
        }
        await choreo.reference.delete();
      }

      // ✅ Delete user document
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      print("✅ All guest data deleted for user: $userId");
    } catch (e) {
      print("❌ Error deleting guest data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Choreographies"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: widget.onOpenSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Search choreographies...",
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh:  () async {
                setState(() {});
                return Future.delayed(Duration(milliseconds: 500));
              },
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _choreosStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("Tap the plus icon to create your first choreography!"));
                }

                final allChoreos = snapshot.data!;
                // optional search filtering
                final filtered = _isSearching
                    ? allChoreos.where((c) {
                  final name = (c['name'] ?? '').toString().toLowerCase();
                  final level = (c['level'] ?? '').toString().toLowerCase();
                  final styleName = (c['style_name'] ?? '').toString().toLowerCase();
                  final danceName = (c['dance_name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery)
                      || level.contains(_searchQuery)
                      || styleName.contains(_searchQuery)
                      || danceName.contains(_searchQuery);
                }).toList()
                    : allChoreos;

                if (filtered.isEmpty) {
                  return Center(child: Text("No results found."));
                }

                return _buildChoreographyList(filtered);
              },
            ),
          ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Stack(
        children: [
          // If you still want an import from file
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 16),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FloatingActionButton(
                heroTag: "importChoreography",
                onPressed: () async {
                  TextEditingController _shareCodeController = TextEditingController();

                  await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text("Import Choreography"),
                        content: TextField(
                          controller: _shareCodeController,
                          decoration: InputDecoration(labelText: "Enter Share Code"),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("Cancel", style: Theme.of(context).textTheme.titleSmall),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final choreoId = _shareCodeController.text.trim();
                              if (choreoId.isNotEmpty) {
                                try {
                                  await FirestoreService.copyChoreography(choreoId);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text("✅ Choreography imported successfully!"),
                                  ));
                                } catch (e) {
                                  print("❌ ERROR: $e");
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text("❌ Invalid code or choreography not found."),
                                  ));
                                }
                              }
                              Navigator.pop(context);
                            },
                            child: Text("Import"),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Icon(Icons.link),
              ),
            ),
          ),
          // The add choreo button
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 16),
            child: Align(
              alignment: Alignment.bottomRight,
              child: FloatingActionButton(
                heroTag: "addChoreography",
                onPressed: _addChoreography,
                child: Icon(Icons.add),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Instead of grouping by styleId/danceId, let's assume your Firestore doc
  // also stores style_name / dance_name. If you only store IDs, then you must do local lookups:
  Widget _buildChoreographyList(List<Map<String, dynamic>> choreos) {
    print('[DEBUG] Total choreographies: ${choreos.length}');
    choreos.forEach((c) {
      print('''
    Choreo ID: ${c['id']}
    Name: ${c['name']}
    Style: ${c['style_name']} (${c['style_id']})
    Dance: ${c['dance_name']} (${c['dance_id']})
    ---------------------''');
    });

    if (_isSearching) {
      return ListView(
        children: choreos.map((choreo) => _buildChoreoItem(choreo)).toList(),
      );
    }

    final grouped = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (var c in choreos) {
      final style = (c['style_name'] ?? '(Unknown Style)') as String;
      final dance = (c['dance_name'] ?? '(Unknown Dance)') as String;
      grouped.putIfAbsent(style, () => {});
      grouped[style]!.putIfAbsent(dance, () => []);
      grouped[style]![dance]!.add(c);
    }

    return ListView(
      children: grouped.entries.map((styleEntry) {
        final style = styleEntry.key;
        final dances = styleEntry.value;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
          child: ExpansionTile(
            title: Text(style),
            children: dances.entries.map((danceEntry) {
              final dance = danceEntry.key;
              final items = danceEntry.value;
              return ExpansionTile(
                title: Text(dance),
                children: items.isEmpty
                    ? [ListTile(title: Text("No choreographies available."))]
                    : items.map((choreo) => _buildChoreoItem(choreo)).toList(),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChoreoItem(Map<String, dynamic> c) {
    final name = c['name']?.toString() ?? 'Unnamed Choreography';
    final style = c['style_name']?.toString() ?? 'Unknown Style';
    final dance = c['dance_name']?.toString() ?? 'Unknown Dance';

    return ListTile(
      title: Text(name),
      subtitle: Text("$style - $dance - ${c['level'] ?? ''}", style: Theme.of(context).textTheme.titleSmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _editChoreography(c),
              color: Theme.of(context).colorScheme.secondary
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => _deleteChoreography(c),
            color: Theme.of(context).colorScheme.error
          ),
        ],
      ),
      onTap: () => _viewChoreography(c),
    );
  }
}