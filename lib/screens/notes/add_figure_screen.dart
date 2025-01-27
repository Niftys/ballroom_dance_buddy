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

  @override
  void initState() {
    super.initState();
    _loadAvailableFigures();
  }

  Future<void> _loadAvailableFigures() async {
    try {
      final figures = await DatabaseService.getFigures(
        styleId: widget.styleId,
        danceId: widget.danceId,
        level: widget.level,
      );

      final customFigures = await DatabaseService.getCustomFiguresByStyleAndDance(
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

  Map<String, List<Map<String, dynamic>>> _groupFiguresByLevel(List<Map<String, dynamic>> figures) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final figure in figures) {
      final level = figure['level'] as String;
      grouped[level] = (grouped[level] ?? [])..add(figure);
    }

    return grouped;
  }

  void _addFigure(int figureId) async {
    try {
      final choreographyFigureId = await DatabaseService.addFigureToChoreography(
        choreographyId: widget.choreographyId,
        figureId: figureId,
      );

      if (kDebugMode) {
        print("Figure added to choreography with ID: $choreographyFigureId");
      }
      _loadAvailableFigures(); // Refresh the list after adding
      Navigator.pop(context, true); // Close and refresh the View Choreography screen
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
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Optional: Adjust padding
                ),
                child: Text(
                  "Cancel",
                  style: Theme.of(context).textTheme.titleSmall, // Apply text style here
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
      _loadAvailableFigures(); // Refresh the list after deletion
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
        title: Text("Add Figure", style: Theme.of(context).textTheme.titleLarge),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _organizedFigures.isEmpty
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
          : ListView(
        children: _organizedFigures.entries.map((entry) {
          final level = entry.key;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ExpansionTile(
              title: Text(
                level,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: level == 'Bronze'
                      ? AppColors.bronze
                      : level == 'Silver'
                      ? AppColors.silver
                      : level == 'Gold'
                      ? AppColors.gold
                      : Theme.of(context).colorScheme.secondary,
                ),
              ),
              children: entry.value.map((figure) {
                return ListTile(
                  title: Text(figure['description']),
                  onTap: () => _addFigure(figure['id']),
                  trailing: figure['custom'] == 1
                      ? IconButton(
                    icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                    onPressed: () => _deleteCustomFigure(figure['id']),
                  )
                      : null,
                );
              }).toList(),
            ),
          );
        }).toList(),
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
}