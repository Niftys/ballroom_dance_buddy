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

      // Fetch custom figures linked to the choreography
      final customFigures = await DatabaseService.getFiguresForChoreography(widget.choreographyId);

      final organized = {
        'Bronze': figures.where((f) => f['level'] == 'Bronze').toList(),
        'Silver': figures.where((f) => f['level'] == 'Silver').toList(),
        'Gold': figures.where((f) => f['level'] == 'Gold').toList(),
        'Custom': customFigures.where((f) => f['custom'] == 1).toList(), // Custom figures
      };

      if (widget.level == 'Bronze') {
        organized.removeWhere((key, value) => key != 'Bronze' && key != 'Custom');
      } else if (widget.level == 'Silver') {
        organized.removeWhere((key, value) => key == 'Gold' && key != 'Custom');
      }

      setState(() {
        _organizedFigures = organized;
      });
    } catch (e) {
      print("Error loading figures: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load figures")),
      );
    }
  }

  void _addFigure(int figureId) async {
    try {
      await DatabaseService.addFigureToChoreography(
        choreographyId: widget.choreographyId,
        figureId: figureId,
      );
      _loadAvailableFigures(); // Refresh the UI
      Navigator.pop(context, true); // Ensure single navigation
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
        await DatabaseService.addCustomFigure(
          choreographyId: widget.choreographyId,
          description: result['description']!,
          notes: result['notes'] ?? '',
        );
        _loadAvailableFigures(); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add custom figure")),
        );
      }
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