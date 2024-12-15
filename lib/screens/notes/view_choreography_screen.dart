import 'package:flutter/material.dart';
import '/services/database_service.dart';
import 'add_figure_screen.dart';

class ViewChoreographyScreen extends StatefulWidget {
  final int choreographyId;
  final int styleId;
  final int danceId;
  final String level;

  ViewChoreographyScreen({
    required this.choreographyId,
    required this.styleId,
    required this.danceId,
    required this.level,
  });

  @override
  _ViewChoreographyScreenState createState() => _ViewChoreographyScreenState();
}

class _ViewChoreographyScreenState extends State<ViewChoreographyScreen> {
  List<Map<String, dynamic>> _figures = [];

  @override
  void initState() {
    super.initState();
    _loadFigures();
  }

  Future<void> _loadFigures() async {
    if (!mounted) return;
    try {
      final figures = await DatabaseService.getFiguresForChoreography(widget.choreographyId);
      setState(() {
        _figures = figures;
      });
    } catch (e) {
      print("Error loading figures: $e");
    }
  }

  void _reorderFigures(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;

    setState(() {
      // Create a mutable copy of the list
      final List<Map<String, dynamic>> updatedFigures = List.from(_figures);

      // Reorder the list
      final figure = updatedFigures.removeAt(oldIndex);
      updatedFigures.insert(newIndex, figure);

      // Update the local state
      _figures = updatedFigures;
    });

    try {
      // Update the database with the new positions
      for (int i = 0; i < _figures.length; i++) {
        await DatabaseService.updateFigureOrder(
          choreographyFigureId: _figures[i]['choreography_figure_id'], // Unique ID for the figure
          newPosition: i, // New position in the list
        );
      }
    } catch (e) {
      print("Error updating figure order: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update figure order.")),
      );
    }
  }

  void _editNotes(int? choreographyFigureId, String currentNotes) async {
    if (choreographyFigureId == null) {
      print("Error: choreographyFigureId is null. Cannot edit notes.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: Unable to edit notes for this figure.")),
      );
      return;
    }

    final TextEditingController _notesController = TextEditingController(text: currentNotes);

    final updatedNotes = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Notes"),
          content: TextField(
            controller: _notesController,
            decoration: InputDecoration(labelText: "Notes"),
            maxLines: null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _notesController.text),
              child: Text("Save"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text("Cancel"),
            ),
          ],
        );
      },
    );

    if (updatedNotes != null) {
      try {
        await DatabaseService.updateFigureNotes(choreographyFigureId, updatedNotes);
        await _loadFigures(); // Refresh the figures to show updated notes
      } catch (e) {
        print("Error updating notes: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update notes.")),
        );
      }
    }
  }

  void _addFigure() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddFigureScreen(
          choreographyId: widget.choreographyId,
          styleId: widget.styleId,
          danceId: widget.danceId,
          level: widget.level,
        ),
      ),
    );

    if (result == true) {
      _loadFigures();
    }
  }

  void _removeFigure(int? choreographyFigureId) async {
    if (choreographyFigureId == null) {
      print("Error: choreographyFigureId is null. Cannot delete figure.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: Unable to delete this figure.")),
      );
      return;
    }

    try {
      await DatabaseService.removeFigureFromChoreography(choreographyFigureId: choreographyFigureId);
      _loadFigures();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Figure deleted successfully.")),
      );
    } catch (e) {
      print("Error removing figure: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete figure.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("View Choreography")),
      body: _figures.isEmpty
          ? Center(child: Text("No figures added yet."))
          : ReorderableListView(
        onReorder: _reorderFigures,
        children: List.generate(_figures.length, (index) {
          final figure = _figures[index];
          return ListTile(
            key: ValueKey('${figure['choreography_figure_id']}_${index}'),
            leading: Icon(Icons.drag_handle, color: Colors.grey),
            title: Text(figure['description']),
            subtitle: figure['notes'] != null && figure['notes'].isNotEmpty
                ? Text(figure['notes'])
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _editNotes(
                    figure['choreography_figure_id'], // Pass choreography_figure_id
                    figure['notes'] ?? '',
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeFigure(figure['choreography_figure_id']),
                ),
              ],
            ),
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFigure,
        child: Icon(Icons.add),
      ),
    );
  }
}