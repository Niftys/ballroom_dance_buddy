import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// local imports
import '../../login.dart';
import 'add_choreography_screen.dart';
import 'view_choreography_screen_firestore.dart';
// If you need local style/dance name lookups:
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
    if (user == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('choreographies')
        .where('uid', isEqualTo: user.uid)  // Only fetch user-specific choreographies
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
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
                onPressed: () {
                  // do your old import logic or remove this
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
    // group them by style_name => dance_name if you want expansions
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
    return ListTile(
      title: Text(c['name'] ?? 'Unnamed'),
      subtitle: Text("${c['level'] ?? ''}"),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _editChoreography(c),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => _deleteChoreography(c),
          ),
        ],
      ),
      onTap: () => _viewChoreography(c),
    );
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
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(docId)
          .delete();
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }
}