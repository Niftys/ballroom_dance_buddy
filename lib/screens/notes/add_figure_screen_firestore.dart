import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../themes/colors.dart';
import '/services/database_service.dart';

class AddFigureScreenFirestore extends StatefulWidget {
  final String choreoDocId;
  final int styleId;
  final int danceId;
  final String level;

  const AddFigureScreenFirestore({
    Key? key,
    required this.choreoDocId,
    required this.styleId,
    required this.danceId,
    required this.level,
  }) : super(key: key);

  @override
  _AddFigureScreenFirestoreState createState() => _AddFigureScreenFirestoreState();
}

class _AddFigureScreenFirestoreState extends State<AddFigureScreenFirestore> {
  Map<String, List<Map<String, dynamic>>> _organizedFigures = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String? _selectedLevel;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAvailableFigures();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _loadAvailableFigures() async {
    try {
      List<Map<String, dynamic>> figures = List.from(
        await DatabaseService.getFigures(
          styleId: widget.styleId,
          danceId: widget.danceId,
          level: widget.level,
        ),
      );

      final userId = FirebaseAuth.instance.currentUser!.uid;
      final figuresSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(widget.choreoDocId) // ✅ Load only figures from this choreography
          .collection('figures')
          .get();

      final customFigures = figuresSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      figures.addAll(customFigures);

      final Map<String, List<Map<String, dynamic>>> organized = _groupFiguresByLevel(figures);
      setState(() {
        _organizedFigures = organized;
      });
    } catch (e) {
      print("Error loading figures: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load figures.")),
      );
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupFiguresByLevel(
      List<Map<String, dynamic>> figures) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final figure in figures) {
      final level = figure['level'] as String;
      grouped.putIfAbsent(level, () => []).add(figure);
    }
    return grouped;
  }

  Future<void> _addFigureToFirestore(Map<String, dynamic> figure) async {
    try {
      final nextPosition = await _getNextPosition();
      final userId = FirebaseAuth.instance.currentUser!.uid;

      final figureData = {
        'description': figure['description'],
        'notes': figure['notes'] ?? '',
        'level': figure['level'] ?? 'Bronze',
        'position': nextPosition,
        'custom': figure['custom'] ?? false,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(widget.choreoDocId)
          .collection('figures')
          .add(figureData);

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add figure: $e")),
      );
    }
  }

  Future<int> _getNextPosition() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(widget.choreoDocId)
        .collection('figures')
        .orderBy('position', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      final currentMax = snap.docs.first.data()['position'] ?? 0;
      return currentMax + 1;
    }
    return 0;
  }

  void _addCustomFigure() async {
    final TextEditingController _descriptionController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add Custom Figure"),
          content: TextField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: "Description"),
            onSubmitted: (_) => _saveCustomFigure(_descriptionController.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text("Cancel", style: Theme.of(context).textTheme.titleSmall),
            ),
            ElevatedButton(
              onPressed: () async {
                final description = _descriptionController.text.trim();
                if (description.isNotEmpty) {
                  final userId = FirebaseAuth.instance.currentUser!.uid;
                  final customFigure = {
                    'description': description,
                    'level': 'Custom',
                    'notes': '',
                    'created_by': userId,
                  };

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('custom_figures')
                      .add(customFigure);

                  await _loadAvailableFigures();
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Description cannot be empty.")),
                  );
                }
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await _loadAvailableFigures();
    }
  }

  void _saveCustomFigure(String description) async {
    if (description.trim().isNotEmpty) {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final customFigure = {
        'description': description.trim(),
        'level': 'Custom',
        'notes': '',
        'created_by': userId,
        'custom': true,
      };

      // ✅ Save inside the choreography instead of globally
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(widget.choreoDocId) // Ensure it's saved inside the correct choreography
          .collection('figures') // Store it alongside normal figures
          .add(customFigure);

      setState(() {
        _organizedFigures['Custom'] ??= [];
        _organizedFigures['Custom']!.add({...customFigure, 'id': docRef.id, 'custom': true});
      });

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Description cannot be empty.")),
      );
    }
  }

  List<Map<String, dynamic>> _filterFigures(List<Map<String, dynamic>> figures) {
    if (_searchQuery.isEmpty) return figures;
    return figures.where((f) {
      final desc = (f['description'] ?? '').toString().toLowerCase();
      return desc.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Figure"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search figures...",
                prefixIcon: Icon(Icons.search),
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults()
                : _buildDefaultFigureList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "addCustomFigure",
        onPressed: _addCustomFigure,
        child: Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }

  Widget _buildSearchResults() {
    final allFigures = _organizedFigures.values.expand((list) => list).toList();
    final searchResults = _filterFigures(allFigures);

    if (searchResults.isEmpty) {
      return Center(
        child: Text("No figures found."),
      );
    }

    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final figure = searchResults[index];
        return ListTile(
          title: Text(figure['description'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(figure['level'] ?? '', style: Theme.of(context).textTheme.titleSmall),
          onTap: () => _addFigureToFirestore(figure),
        );
      },
    );
  }

  Widget _buildDefaultFigureList() {
    if (_organizedFigures.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    return StatefulBuilder(builder: (context, setState) {
      const desiredOrder = [
        'Bronze', 'Silver', 'Gold',
        'Newcomer IV', 'Newcomer III', 'Newcomer II',
        'Custom'
      ];

      final sortedLevels = _organizedFigures.keys.toList()
        ..sort((a, b) {
          final indexA = desiredOrder.indexOf(a);
          final indexB = desiredOrder.indexOf(b);
          return (indexA == -1 ? 999999 : indexA)
              .compareTo(indexB == -1 ? 999999 : indexB);
        });

      if (_selectedLevel == null && sortedLevels.isNotEmpty) {
        _selectedLevel = sortedLevels.first;
      }

      return Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              color: Theme.of(context).colorScheme.surface.withAlpha(50),
              child: ListView(
                children: sortedLevels.map((level) {
                  final levelColor = _getLevelColor(level);
                  final isSelected = (_selectedLevel == level);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedLevel = level),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? levelColor.withAlpha(75)
                            : Colors.transparent,
                        border: Border(
                          left: BorderSide(
                            color: isSelected
                                ? levelColor
                                : Colors.transparent,
                            width: 4.0,
                          ),
                        ),
                      ),
                      child: Text(
                        level,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Container(width: 2, color: Colors.grey),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).colorScheme.surface,
              child: _selectedLevel == null
                  ? Center(child: Text("Select a level"))
                  : ListView(
                children: (_organizedFigures[_selectedLevel] ?? []).map((figure) {
                  return ListTile(
                    visualDensity: VisualDensity(vertical: 1),
                    title: Text(figure['description'] ?? 'Unnamed'),
                    onTap: () => _addFigureToFirestore(figure),
                    trailing: (figure['custom'] == true)
                        ? IconButton(
                      icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                      onPressed: () => _deleteLocalCustomFigure(figure),
                    )
                        : null,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      );
    });
  }

  void _deleteLocalCustomFigure(Map<String, dynamic> figure) async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final figureId = figure['id'];

      // ✅ Delete only from the specific choreography
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(widget.choreoDocId) // ✅ Ensure it's deleted only from this choreography
          .collection('figures')
          .doc(figureId)
          .delete();

      _loadAvailableFigures(); // Refresh UI
    } catch (e) {
      print("Error deleting custom figure: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete custom figure.")),
      );
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'Bronze':
        return AppColors.bronze;
      case 'Silver':
        return AppColors.silver;
      case 'Gold':
        return AppColors.gold;
      case 'Newcomer IV':
      case 'Newcomer III':
      case 'Newcomer II':
        return AppColors.primary;
      case 'Custom':
        return AppColors.highlight;
      default:
        return AppColors.highlight;
    }
  }
}