import 'package:flutter/material.dart';
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

      print("Organized figures by levels: ${organized.keys}");

      organized.removeWhere((key, value) => value.isEmpty);

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

      print("Figure added to choreography with ID: $choreographyFigureId");
      _loadAvailableFigures();  // Refresh the list after adding
      Navigator.pop(context, true);  // Close and refresh the View Choreography screen
    } catch (e) {
      print("Error adding figure: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add figure")),
      );
    }
  }

  void _addCustomFigure() async {
    final TextEditingController _descriptionController = TextEditingController();
    final TextEditingController _notesController = TextEditingController();

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
              TextField(
                controller: _notesController,
                decoration: InputDecoration(labelText: "Notes"),
                maxLines: null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, {
                'description': _descriptionController.text,
                'notes': _notesController.text,
              }),
              child: Text("Save"),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        final figureId = await DatabaseService.addCustomFigure(
          choreographyId: widget.choreographyId,
          styleId: widget.styleId,
          danceId: widget.danceId,
          description: result['description']!,
          notes: result['notes'] ?? '',
        );

        _loadAvailableFigures();  // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add custom figure.")),
        );
      }
    }
  }

  void _deleteCustomFigure(int figureId) async {
    try {
      await DatabaseService.deleteCustomFigure(figureId);
      _loadAvailableFigures();  // Refresh the list after deletion
    } catch (e) {
      print("Error deleting custom figure: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete custom figure.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 6,
        backgroundColor: Colors.white,
        shadowColor: Colors.black26,
        title: Text("Add Figure", style: TextStyle(color: Colors.black87)),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.deepPurple),
            onPressed: _addCustomFigure,
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _organizedFigures.isEmpty
          ? Center(child: CircularProgressIndicator(color: Colors.purple))
          : ListView(
        children: _organizedFigures.entries.map((entry) {
          final level = entry.key;
          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ExpansionTile(
              title: Text(
                level,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: level == 'Bronze'
                      ? Colors.brown
                      : level == 'Silver'
                      ? Colors.grey
                      : level == 'Gold'
                      ? Colors.amber
                      : Colors.deepPurple,
                ),
              ),
              children: entry.value.map((figure) {
                return ListTile(
                  title: Text(figure['description']),
                  onTap: () => _addFigure(figure['id']),
                  trailing: figure['custom'] == 1
                      ? IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteCustomFigure(figure['id']),
                  )
                      : null,
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
      backgroundColor: Colors.grey.shade100,
    );
  }
}