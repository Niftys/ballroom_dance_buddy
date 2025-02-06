import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../themes/colors.dart';
import '/services/database_service.dart';

class AddFigureScreen extends StatefulWidget {
  final int choreographyId;
  final int styleId;
  final int danceId;
  final String level;

  AddFigureScreen({
    required this.choreographyId,
    required this.styleId,
    required this.danceId,
    required this.level,
  });

  @override
  _AddFigureScreenState createState() => _AddFigureScreenState();
}

class _AddFigureScreenState extends State<AddFigureScreen> {
  Map<String, List<Map<String, dynamic>>> _organizedFigures = {};
  String _searchQuery = '';
  String? _selectedLevel;
  final TextEditingController _searchController = TextEditingController();

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
      final figures = await DatabaseService.getFigures(
        styleId: widget.styleId,
        danceId: widget.danceId,
        level: widget.level,
      );

      final customFigures = await DatabaseService
          .getCustomFiguresByStyleAndDance(
        styleId: widget.styleId,
        danceId: widget.danceId,
      );

      // Group figures by level
      final organized = _groupFiguresByLevel(figures);
      organized['Custom'] = customFigures;

      if (kDebugMode) {
        print("Organized figures by levels: ${organized.keys}");
      }

      organized.removeWhere((key, value) => value.isEmpty);

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

  Map<String, List<Map<String, dynamic>>> _groupFiguresByLevel(
      List<Map<String, dynamic>> figures) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final figure in figures) {
      final level = figure['level'] as String;
      grouped[level] = (grouped[level] ?? [])
        ..add(figure);
    }

    return grouped;
  }

  List<Map<String, dynamic>> _filterFigures(
      List<Map<String, dynamic>> figures) {
    if (_searchQuery.isEmpty) return figures;
    return figures
        .where((figure) =>
        figure['description']
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _addFigure(int figureId) async {
    try {
      final choreographyFigureId = await DatabaseService
          .addFigureToChoreography(
        choreographyId: widget.choreographyId,
        figureId: figureId,
      );

      if (kDebugMode) {
        print("Figure added to choreography with ID: $choreographyFigureId");
      }
      _loadAvailableFigures(); // Refresh the list after adding
      Navigator.pop(
          context, true); // Close and refresh the View Choreography screen
    } catch (e) {
      if (kDebugMode) {
        print("Error adding figure: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add figure")),
      );
    }
  }

  void _addCustomFigure() async {
    final TextEditingController _descriptionController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add Custom Figure"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: "Description"),
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.bottomLeft,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16.0,
                          vertical: 8.0), // Optional: Adjust padding
                    ),
                    child: Text(
                      "Cancel",
                      style: Theme
                          .of(context)
                          .textTheme
                          .titleSmall, // Apply text style here
                    ),
                  ),
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
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        await DatabaseService.addCustomFigure(
          description: result['description']!,
          choreographyId: widget.choreographyId,
          styleId: widget.styleId,
          danceId: widget.danceId,
        );
        print("Custom figure added: ${result['description']}");
        _loadAvailableFigures(); // Refresh the list
      } catch (e) {
        print("Error adding custom figure: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add custom figure.")),
        );
      }
    }
  }

  void _deleteCustomFigure(int figureId) async {
    try {
      await DatabaseService.deleteCustomFigure(figureId);
      _loadAvailableFigures();

      setState(() {
        if (_organizedFigures.containsKey('Custom') && _organizedFigures['Custom']!.isEmpty) {
          _organizedFigures.remove('Custom');  // Remove the key if it's empty
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error deleting custom figure: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete custom figure.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Figure", style: Theme
            .of(context).textTheme.titleLarge),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Box
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
                ? _buildSearchResults() // Show search results
                : _buildDefaultFigureList(), // Show folder structure
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

// Build flat list of search results
  Widget _buildSearchResults() {
    final List<
        Map<String, dynamic>> allFigures = _getAllFigures(); // Flattened list
    final List<Map<String, dynamic>> searchResults =
    _filterFigures(allFigures); // Filter by search query

    if (searchResults.isEmpty) {
      return Center(
        child: Text(
          "No figures found.",
          style: Theme
              .of(context).textTheme.bodyLarge,
        ),
      );
    }

    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final figure = searchResults[index];
        return ListTile(
          title: Text(figure['description'], style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(figure['level'], style: Theme.of(context).textTheme.titleSmall),
          onTap: () => _addFigure(figure['id']),
          trailing: figure['custom'] == 1
              ? IconButton(
            icon: Icon(Icons.delete, color: Theme
                .of(context).colorScheme.error),
            onPressed: () => _deleteCustomFigure(figure['id']),
          )
              : null,
        );
      },
    );
  }

// Build default folder structure
  Widget _buildDefaultFigureList() {
    if (_organizedFigures.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }

    return StatefulBuilder(builder: (context, setState) {
      // Define desired order
      const desiredOrder = [
        'Bronze', 'Silver', 'Gold',
        'Newcomer IV', 'Newcomer III', 'Newcomer II', 'Custom'
      ];

      // Sort levels
      final sortedLevels = _organizedFigures.keys.toList()
        ..sort((a, b) {
          final indexA = desiredOrder.indexOf(a);
          final indexB = desiredOrder.indexOf(b);
          return (indexA == -1 ? double.infinity : indexA.toDouble())
              .compareTo(indexB == -1 ? double.infinity : indexB.toDouble());
        });

      // Select first level if none selected
      if (_selectedLevel == null && sortedLevels.isNotEmpty) {
        _selectedLevel = sortedLevels.first;
      }

      return Row(
        children: [
          // Left Panel - Level Selection
          Expanded(
            flex: 1,
            child: Container(
              color: Theme.of(context).colorScheme.surface.withAlpha(50),
              child: ListView(
                children: sortedLevels.map((level) {
                  final levelColor = _getLevelColor(level);

                  return GestureDetector(
                    onTap: () => setState(() => _selectedLevel = level),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: _selectedLevel == level
                            ? levelColor.withAlpha(75)
                            : Colors.transparent,
                        border: Border(
                          left: BorderSide(
                            color: _selectedLevel == level
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
          Container(
            width: 2,
            color: Colors.grey,
          ),
          // Right Panel - Figures List
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).colorScheme.surface,
              child: _selectedLevel == null
                  ? Center(
                child: Text(
                  "Select a level",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              )
                  : ListView(
                children: (_organizedFigures[_selectedLevel] ?? []).map((figure) {
                  return ListTile(
                    visualDensity: VisualDensity(vertical: 1),
                    title: Text(
                      figure['description'],
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => _addFigure(figure['id']),
                    trailing: figure['custom'] == 1
                        ? IconButton(
                      icon: Icon(Icons.delete,
                          color: Theme.of(context).colorScheme.error),
                      onPressed: () => _deleteCustomFigure(figure['id']),
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
      default:
        return AppColors.highlight;
    }
  }

// Helper method to get all figures as a flat list
  List<Map<String, dynamic>> _getAllFigures() {
    return _organizedFigures.values.expand((figures) => figures).toList();
  }
}