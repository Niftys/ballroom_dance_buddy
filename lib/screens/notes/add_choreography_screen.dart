import 'package:flutter/material.dart';
import '/services/database_service.dart';

class AddChoreographyScreen extends StatefulWidget {
  final Function onSave;

  AddChoreographyScreen({required this.onSave});

  @override
  _AddChoreographyScreenState createState() => _AddChoreographyScreenState();
}

class _AddChoreographyScreenState extends State<AddChoreographyScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedStyle;
  String? _selectedDance;
  String? _selectedLevel;

  List<String> _styles = [];
  List<String> _availableDances = [];
  final List<String> _levels = ['Bronze', 'Silver', 'Gold'];

  @override
  void initState() {
    super.initState();
    _loadStyles();
  }

  Future<void> _loadStyles() async {
    try {
      final styles = await DatabaseService.getAllStyles();
      setState(() {
        _styles = styles.map((style) => style['name'] as String).toList();
        if (_styles.isNotEmpty) {
          _selectedStyle = _styles.first;
          _loadDancesForStyle(_selectedStyle!);
        }
      });
    } catch (e) {
      print("Error loading styles: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load styles")),
      );
    }
  }

  Future<void> _loadDancesForStyle(String styleName) async {
    try {
      final styleId = await DatabaseService.getStyleIdByName(styleName);
      final dances = await DatabaseService.getDancesByStyleId(styleId);
      setState(() {
        _availableDances = dances.map((dance) => dance['name'] as String).toList();
        _selectedDance = _availableDances.isNotEmpty ? _availableDances.first : null;
      });
    } catch (e) {
      print("Error loading dances: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load dances")),
      );
    }
  }

  void _saveChoreography() async {
    if (_nameController.text.isEmpty ||
        _selectedStyle == null ||
        _selectedDance == null ||
        _selectedLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    try {
      final styleId = await DatabaseService.getStyleIdByName(_selectedStyle!);
      final danceId = await DatabaseService.getDanceIdByNameAndStyle(_selectedDance!, styleId);

      await DatabaseService.addChoreography(
        name: _nameController.text,
        styleId: styleId,
        danceId: danceId,
        level: _selectedLevel!,
      );

      widget.onSave(); // Refresh the parent screen
      Navigator.pop(context); // Close the screen
    } catch (e) {
      print("Error saving choreography: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save choreography: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Choreography")),
      body: _styles.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: "Choreography Name"),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedStyle,
              items: _styles
                  .map((style) => DropdownMenuItem(value: style, child: Text(style)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStyle = value!;
                  _availableDances = [];
                  _selectedDance = null;
                });
                _loadDancesForStyle(_selectedStyle!);
              },
              decoration: InputDecoration(labelText: "Style"),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedDance,
              items: _availableDances
                  .map((dance) => DropdownMenuItem(value: dance, child: Text(dance)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDance = value!;
                });
              },
              decoration: InputDecoration(labelText: "Dance"),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedLevel,
              items: _levels
                  .map((level) => DropdownMenuItem(value: level, child: Text(level)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLevel = value!;
                });
              },
              decoration: InputDecoration(labelText: "Level"),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: _saveChoreography,
              child: Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
