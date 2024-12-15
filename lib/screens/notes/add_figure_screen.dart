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
  List<Map<String, dynamic>> _availableFigures = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableFigures();
  }

  Future<void> _loadAvailableFigures() async {
    try {
      // Fetch all figures for the specified style, dance, and level
      final figures = await DatabaseService.getFigures(
        styleId: widget.styleId,
        danceId: widget.danceId,
        level: widget.level,
      );

      setState(() {
        _availableFigures = figures;
      });
    } catch (e) {
      print("Error loading figures: $e");
    }
  }

  void _addFigure(int figureId) async {
    try {
      await DatabaseService.addFigureToChoreographyAsNewEntry(
        choreographyId: widget.choreographyId,
        figureId: figureId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Figure added successfully")),
      );

      Navigator.pop(context, true); // Send success signal back to ViewChoreographyScreen
    } catch (e) {
      print("Error adding figure: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add figure")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Figure")),
      body: _availableFigures.isEmpty
          ? Center(child: Text("No figures available"))
          : ListView.builder(
        itemCount: _availableFigures.length,
        itemBuilder: (context, index) {
          final figure = _availableFigures[index];
          return ListTile(
            title: Text(figure['description']),
            trailing: Icon(Icons.add, color: Colors.green), // Add icon for clarity
            onTap: () => _addFigure(figure['id']), // Add the figure when tapped
          );
        },
      ),
    );
  }
}
