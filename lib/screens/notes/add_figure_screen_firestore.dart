import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Keep DatabaseService ONLY IF you want to load the standard figure definitions
// from your local JSON. We won't call any write methods from it.
import '../../themes/colors.dart';
import '/services/database_service.dart';

/// A Firestore-based "Add Figure" screen that:
/// 1) Shows available figures from local data (grouped by level).
/// 2) Lets user search or select a figure to add.
/// 3) Writes each figure as a doc in Firestore under choreographies/{choreoDocId}/figures.
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
  // Organized as: { "Bronze": [ {id, description, ...}, ... ], "Silver": [...], ... }
  Map<String, List<Map<String, dynamic>>> _organizedFigures = {};

  // For searching
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Which level tab is selected on the left panel
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

  /// Handle live search text changes
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  /// Load standard figures from local data or JSON
  /// and group them by level (e.g. Bronze, Silver, etc.).
  Future<void> _loadAvailableFigures() async {
    try {
      // 1) Load standard or recommended figures from local data
      final figures = await DatabaseService.getFigures(
        styleId: widget.styleId,
        danceId: widget.danceId,
        level: widget.level,
      );

      // 2) If you still want to find custom definitions, you can do so:
      final customFigures = await DatabaseService.getCustomFiguresByStyleAndDance(
        styleId: widget.styleId,
        danceId: widget.danceId,
      );

      // 3) Group them by 'level'
      final Map<String, List<Map<String, dynamic>>> organized = _groupFiguresByLevel(figures);
      if (customFigures.isNotEmpty) {
        organized['Custom'] = customFigures;
      }

      // Remove empty groups
      organized.removeWhere((_, list) => list.isEmpty);

      setState(() {
        _organizedFigures = organized;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error loading figures: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load figures.")),
      );
    }
  }

  /// Local helper to group a list of figures by their 'level' field
  Map<String, List<Map<String, dynamic>>> _groupFiguresByLevel(
      List<Map<String, dynamic>> figures) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final figure in figures) {
      final level = figure['level'] as String;
      grouped.putIfAbsent(level, () => []).add(figure);
    }
    return grouped;
  }

  /// Create a new figure doc in the sub-collection, e.g.
  /// choreographies/{choreoDocId}/figures.
  /// We'll do a position-based approach so you can reorder them later.
  Future<void> _addFigureToFirestore(Map<String, dynamic> figure) async {
    try {
      final nextPosition = await _getNextPosition();

      await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(widget.choreoDocId)
          .collection('figures')
          .add({
        'description': figure['description'],
        'notes': figure['notes'] ?? '',
        'level': figure['level'] ?? 'Bronze',
        'position': nextPosition,
      });

      Navigator.pop(context, true);  // Go back after adding figure
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add figure: $e")),
      );
    }
  }

  /// If you want them sorted by a 'position' field, find the largest position so far
  /// and add 1. If no existing docs, position=0.
  Future<int> _getNextPosition() async {
    final snap = await FirebaseFirestore.instance
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

  /// For custom figure creation: user enters a new name,
  /// we store it as `level: 'Custom'`, `notes: ''`, etc.
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final description = _descriptionController.text.trim();
                if (description.isNotEmpty) {
                  Navigator.pop(context, {'description': description});
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
      // We treat it as a brand new figure with 'Custom' level
      final newFig = {
        'description': result['description']!,
        'level': 'Custom',
        'notes': '',
      };
      await _addFigureToFirestore(newFig);
    }
  }

  /// Searching over all figures
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
        title: Text("Add Figure (Firestore)"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search box
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
          // The main area
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

  /// If the user typed something in the search box,
  /// we flatten all levels into one list, filter them, and show them.
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
          title: Text(figure['description'] ?? 'Unknown'),
          subtitle: Text(figure['level'] ?? ''),
          onTap: () => _addFigureToFirestore(figure),
        );
      },
    );
  }

  /// If the search is blank, we show the "folder structure" by level:
  /// left panel of levels, right panel of figures for that level.
  Widget _buildDefaultFigureList() {
    if (_organizedFigures.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    return StatefulBuilder(builder: (context, setState) {
      // We define a desired order for levels, e.g. Bronze, Silver, Gold, etc.
      const desiredOrder = [
        'Bronze', 'Silver', 'Gold',
        'Newcomer IV', 'Newcomer III', 'Newcomer II',
        'Custom'
      ];

      // Sort the map keys
      final sortedLevels = _organizedFigures.keys.toList()
        ..sort((a, b) {
          final indexA = desiredOrder.indexOf(a);
          final indexB = desiredOrder.indexOf(b);
          return (indexA == -1 ? 999999 : indexA)
              .compareTo(indexB == -1 ? 999999 : indexB);
        });

      // If no level selected yet, pick the first
      if (_selectedLevel == null && sortedLevels.isNotEmpty) {
        _selectedLevel = sortedLevels.first;
      }

      return Row(
        children: [
          // Left panel: list of levels
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
          // Divider
          Container(width: 2, color: Colors.grey),
          // Right panel: figures for the selected level
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
                    trailing: (figure['custom'] == 1)
                        ? IconButton(
                      icon: Icon(Icons.delete,
                          color: Theme.of(context).colorScheme.error),
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

  /// Optional: if you still handle "delete custom figure" from your local DB
  void _deleteLocalCustomFigure(Map<String, dynamic> figure) async {
    // This only removes it from the local definitions, not from Firestore
    try {
      final figureId = figure['id'];
      await DatabaseService.deleteCustomFigure(figureId);
      _loadAvailableFigures();
    } catch (e) {
      if (kDebugMode) print("Error deleting custom figure: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete custom figure from local.")),
      );
    }
  }

  /// Just for color-coding levels
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
        return Colors.purple; // fallback
    }
  }
}