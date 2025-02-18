import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '/services/database_service.dart'; // Keep only for styles JSON if you want
import 'view_choreography_screen_firestore.dart'; // <-- A new Firestore-based view screen?

class AddChoreographyScreen extends StatefulWidget {
  // Instead of int choreographyId, we store the Firestore doc ID
  final String? docId;
  final String? initialName;
  final int? initialStyleId;
  final int? initialDanceId;
  final String? initialLevel;

  // If you want a callback, change the signature to handle docId
  final void Function(String docId, int styleId, int danceId, String level)? onSave;

  AddChoreographyScreen({
    this.docId,
    this.onSave,
    this.initialName,
    this.initialStyleId,
    this.initialDanceId,
    this.initialLevel,
  });

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
  final List<String> _countryWesternLevels = [
    'Newcomer IV',
    'Newcomer III',
    'Newcomer II'
  ];

  @override
  void initState() {
    super.initState();
    // If there's a docId, it means we might be editing
    if (widget.docId != null) {
      _loadStylesForEditing();
    } else {
      _loadStyles();
    }
  }

  Future<void> _loadStyles() async {
    try {
      final stylesAndDances = await DatabaseService.getStylesAndDancesFromJson();
      setState(() {
        _styles = stylesAndDances.keys.toList();
        _selectedStyle = _styles.isNotEmpty ? _styles.first : null;
        _availableDances =
        _selectedStyle != null ? stylesAndDances[_selectedStyle!] ?? [] : [];
        _selectedDance = _availableDances.isNotEmpty ? _availableDances.first : null;
        _selectedLevel = _levels.first;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error loading styles: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load styles")),
      );
    }
  }

  Future<void> _loadStylesForEditing() async {
    try {
      final stylesAndDances = await DatabaseService.getStylesAndDancesFromJson();
      setState(() {
        _styles = stylesAndDances.keys.toList();
      });

      // If you want to pre-fill from widget.initialName, etc.:
      _nameController.text = widget.initialName ?? '';
      _selectedLevel = widget.initialLevel ?? _levels.first;

      // Resolve the style name from ID
      if (widget.initialStyleId != null) {
        final styleName = await DatabaseService.getStyleNameById(widget.initialStyleId!);
        _selectedStyle = styleName;
        _availableDances = stylesAndDances[styleName] ?? [];

        if (widget.initialDanceId != null) {
          final danceName = await DatabaseService.getDanceNameById(widget.initialDanceId!);
          _selectedDance = danceName;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error initializing for editing: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to initialize editor")),
      );
    }
  }

  Future<void> _loadDancesForStyle(String styleName) async {
    try {
      final stylesAndDances = await DatabaseService.getStylesAndDancesFromJson();
      setState(() {
        _availableDances = stylesAndDances[styleName] ?? [];
        _selectedDance = _availableDances.isNotEmpty ? _availableDances.first : null;

        if (styleName.toLowerCase().contains('country western')) {
          _selectedLevel = _countryWesternLevels.first;
        } else {
          _selectedLevel = _levels.first;
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error loading dances for style '$styleName': $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load dances.")),
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
      final danceId = await DatabaseService.getDanceIdByNameAndStyle(
        _selectedDance!,
        styleId,
      );

      String docId;
      if (widget.docId != null) {
        await FirestoreService.updateChoreography(
          choreoDocId: widget.docId!,
          name: _nameController.text,
          styleId: styleId,
          danceId: danceId,
          level: _selectedLevel!,
        );
        docId = widget.docId!;
      } else {
        docId = await FirestoreService.addChoreography(
          name: _nameController.text,
          styleId: styleId,
          danceId: danceId,
          level: _selectedLevel!,
        );
      }

      print("Navigating to View Choreography for $docId");

      // Open the choreography immediately
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ViewChoreographyScreenFirestore(
            choreoDocId: docId,
            styleId: styleId,
            danceId: danceId,
            level: _selectedLevel!,
          ),
        ),
      );
    } catch (e) {
      print("Error saving choreography: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving choreography: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCountryWestern = _selectedStyle?.toLowerCase().contains('country western') ?? false;
    final List<String> levelsToShow = isCountryWestern ? _countryWesternLevels : _levels;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.docId != null ? "Edit Choreography" : "Add Choreography"),
      ),
      body: _styles.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Name field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: "Choreography Name"),
            ),
            SizedBox(height: 20),
            // Style dropdown
            DropdownButtonFormField<String>(
              value: _selectedStyle,
              items: _styles.map((style) {
                return DropdownMenuItem(value: style, child: Text(style));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStyle = value;
                  if (value != null) {
                    _loadDancesForStyle(value);
                  }
                });
              },
              decoration: InputDecoration(labelText: "Style"),
            ),
            SizedBox(height: 20),
            // Dance dropdown
            DropdownButtonFormField<String>(
              value: _selectedDance,
              items: _availableDances.map((dance) {
                return DropdownMenuItem(value: dance, child: Text(dance));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDance = value;
                });
              },
              decoration: InputDecoration(labelText: "Dance"),
            ),
            SizedBox(height: 20),
            // Level dropdown
            DropdownButtonFormField<String>(
              value: _selectedLevel,
              items: levelsToShow.map((level) {
                return DropdownMenuItem(value: level, child: Text(level));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLevel = value;
                });
              },
              decoration: InputDecoration(labelText: "Level"),
            ),
            SizedBox(height: 20),
            // Save button
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
