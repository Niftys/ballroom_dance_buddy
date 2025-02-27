import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../login.dart';
import '../../services/firestore_service.dart';
import 'add_choreography_screen.dart';
import 'view_choreography_screen_firestore.dart';

class NotesScreenFirestore extends StatefulWidget {
  final VoidCallback? onOpenSettings;
  const NotesScreenFirestore({Key? key, this.onOpenSettings}) : super(key: key);

  @override
  _NotesScreenFirestoreState createState() => _NotesScreenFirestoreState();
}

class _NotesScreenFirestoreState extends State<NotesScreenFirestore> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _shareCodeController = TextEditingController();
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

  Stream<Map<String, Map<String, List<Map<String, dynamic>>>>> _groupedChoreosStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('choreographies')
        .snapshots()
        .map((snapshot) {
      final grouped = <String, Map<String, List<Map<String, dynamic>>>>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String style = data['style_name'] ?? 'Unknown Style';
        final String dance = data['dance_name'] ?? 'Unknown Dance';

        grouped.putIfAbsent(style, () => {});
        grouped[style]!.putIfAbsent(dance, () => []);
        grouped[style]![dance]!.add({
          ...data,
          'id': doc.id,
        });
      }
      return grouped;
    });
  }


  void _addChoreography() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddChoreographyScreen(),
      ),
    );
  }

  void _viewChoreography(Map<String, dynamic> c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewChoreographyScreenFirestore(
          choreoDocId: c['id'],
          styleName: c['style_name'] ?? 'Unknown Style',
          danceName: c['dance_name'] ?? 'Unknown Dance',
          level: c['level'] ?? 'Unknown',
        ),
      ),
    );
  }

  void _editChoreography(Map<String, dynamic> c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddChoreographyScreen(
          docId: c['id'],
          initialName: c['name'] ?? '',
          initialStyle: c['style_name'],
          initialDance: c['dance_name'],
          initialLevel: c['level'] ?? 'Bronze',
        ),
      ),
    );
  }

  void _deleteChoreography(Map<String, dynamic> c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Confirm Deletion"),
        content: Text("Are you sure you want to delete '${c['name']}'? This action cannot be undone."),
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

    if (confirmed != true) return;

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      await FirestoreService.deleteChoreography(userId, c['id']);

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Choreography deleted successfully"),
            backgroundColor: Colors.green.shade300,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting choreography: ${e.toString()}"),
            backgroundColor: Colors.red.shade300,
          ),
        );
      }
      print("Delete error: $e");
    }
  }

  void _logout() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      if (user.isAnonymous) {
        try {
          await _deleteUserData(user.uid);
          await user.delete();
        } catch (e) {
          print("Error deleting guest account: $e");
        }
      }
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

      for (final choreo in choreosSnapshot.docs) {
        final figuresSnapshot = await choreo.reference.collection('figures').get();
        for (final figure in figuresSnapshot.docs) {
          await figure.reference.delete();
        }
        await choreo.reference.delete();
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      print("All guest data deleted for user: $userId");
    } catch (e) {
      print("Error deleting guest data: $e");
    }
  }

  Widget _buildEmptyChoreographyMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "No choreographies yet!",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Tap the + button to create your first choreography.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
            child: StreamBuilder<Map<String, Map<String, List<Map<String, dynamic>>>>>(
              stream: _groupedChoreosStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final allChoreos = snapshot.data?.entries.expand((styleEntry) =>
                    styleEntry.value.entries.expand((danceEntry) => danceEntry.value)
                ).map<Map<String, dynamic>>((item) => item).toList() ?? [];

                final filteredChoreos = _isSearching
                    ? allChoreos.where((choreo) {
                  final name = choreo['name']?.toString().toLowerCase() ?? '';
                  final style = choreo['style_name']?.toString().toLowerCase() ?? '';
                  final dance = choreo['dance_name']?.toString().toLowerCase() ?? '';
                  final level = choreo['level']?.toString().toLowerCase() ?? '';

                  return name.contains(_searchQuery) ||
                      style.contains(_searchQuery) ||
                      dance.contains(_searchQuery) ||
                      level.contains(_searchQuery);
                }).toList()
                    : [];

                if (_isSearching) {
                  return _buildChoreographyList(filteredChoreos.cast<Map<String, dynamic>>());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyChoreographyMessage();
                }

                final groupedChoreos = snapshot.data!;
                return _buildGroupedView(groupedChoreos);
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 16),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FloatingActionButton(
                heroTag: "importChoreography",
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text("Import Choreography"),
                        content: TextField(
                          controller: _shareCodeController,
                          decoration: InputDecoration(
                            labelText: "Enter Share Code",
                            hintText: "e.g. CHOREO-abc123",
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("Cancel", style: Theme.of(context).textTheme.titleSmall),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final shareCode = _shareCodeController.text.trim();
                              if (shareCode.isEmpty) return;

                              if (!shareCode.startsWith('CHOREO-')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Import error: Invalid share code format!")),
                                );
                                Navigator.pop(context);
                                return;
                              }
                              final choreoId = shareCode.substring('CHOREO-'.length);

                              try {
                                final userId = FirebaseAuth.instance.currentUser!.uid;
                                await FirestoreService.copyChoreography(choreoId, userId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Choreography imported!")),
                                );
                              } catch (e) {
                                print("Error: $e");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Import error: Choreography is either private or deleted.")),
                                );
                              }
                              Navigator.pop(context);
                              _shareCodeController.clear();
                            },
                            child: Text("Import"),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Icon(Icons.download),
              ),
            ),
          ),
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

  Widget _buildGroupedView(Map<String, Map<String, List<Map<String, dynamic>>>> groupedChoreos) {
    return ListView(
      children: groupedChoreos.entries.map((styleEntry) {
        final String style = styleEntry.key;
        final dances = styleEntry.value;
        return Card(
          margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
          child: ExpansionTile(
            title: Text(style, style: Theme.of(context).textTheme.titleLarge),
            children: dances.entries.map((danceEntry) {
              final String dance = danceEntry.key;
              final choreographies = danceEntry.value;
              return ExpansionTile(
                title: Text(dance, style: Theme.of(context).textTheme.titleMedium),
                children: choreographies.map((choreo) => _buildChoreoItem(choreo)).toList(),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChoreographyList(List<Map<String, dynamic>> choreos) {
    if (choreos.isEmpty) {
      return Center(child: Text("No matching choreographies found"));
    }

    return ListView(
      children: choreos.map((choreo) => _buildChoreoItem(choreo)).toList(),
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
            style: IconButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.secondary,
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => _deleteChoreography(c),
            style: IconButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
      onTap: () => _viewChoreography(c),
    );
  }
}