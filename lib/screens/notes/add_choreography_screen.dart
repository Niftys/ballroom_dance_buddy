import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import 'view_choreography_screen_firestore.dart';

class AddChoreographyScreen extends StatefulWidget {
  final String? docId;
  final String? initialName;
  final String? initialStyle;
  final String? initialDance;
  final String? initialLevel;

  final void Function(String docId, int styleId, int danceId, String level)? onSave;

  AddChoreographyScreen({
    this.docId,
    this.onSave,
    this.initialName,
    this.initialStyle,
    this.initialDance,
    this.initialLevel,
  });

  @override
  _AddChoreographyScreenState createState() => _AddChoreographyScreenState();
}

class _AddChoreographyScreenState extends State<AddChoreographyScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isPublic = false;

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
    if (widget.docId != null) {
      _loadStylesForEditing();
    } else {
      _loadStyles();
    }
  }

  Future<void> _loadStyles() async {
    try {
      final styles = await FirestoreService.getAllStyles();
      styles.sort((a, b) {
        final indexA = _desiredStyleOrder.indexOf(a['name']);
        final indexB = _desiredStyleOrder.indexOf(b['name']);
        return (indexA == -1 ? 999 : indexA).compareTo(indexB == -1 ? 999 : indexB);
      });

      if (mounted) {
        setState(() {
          _styles = styles.map((s) => s['name'] as String).toList();
          _selectedStyle = _styles.isNotEmpty ? _styles.first : null;
          _selectedLevel = _selectedStyle?.toLowerCase().contains('country western') ?? false
              ? _countryWesternLevels.first
              : _levels.first;
          _selectedDance = null;
          _availableDances = [];
          if (_selectedStyle != null) {
            _loadDancesForStyle(_selectedStyle!);
          }
        });
      }
    } catch (e) {
      print("Error loading styles: $e");
    }
  }

  Future<void> _loadStylesForEditing() async {
    try {
      final styles = await FirestoreService.getAllStyles();
      styles.sort((a, b) {
        final indexA = _desiredStyleOrder.indexOf(a['name']);
        final indexB = _desiredStyleOrder.indexOf(b['name']);
        return (indexA == -1 ? 999 : indexA).compareTo(indexB == -1 ? 999 : indexB);
      });

      if (mounted) {
        setState(() {
          _styles = styles.map((s) => s['name'] as String).toList();
          _selectedStyle = widget.initialStyle;
          _selectedDance = widget.initialDance;
          _selectedLevel = widget.initialLevel ??
              (widget.initialStyle?.toLowerCase().contains('country western') ?? false
                  ? _countryWesternLevels.first
                  : _levels.first);
        });
      }

      _nameController.text = widget.initialName ?? '';

      if (widget.initialStyle != null) {
        await _loadDancesForStyle(widget.initialStyle!, initialDance: widget.initialDance);
      }
    } catch (e) {
      print("Error initializing for editing: $e");
    }
  }

  Future<void> _loadDancesForStyle(String styleName, {String? initialDance}) async {
    try {
      final dances = await FirestoreService.getDancesByStyleName(styleName);
      dances.sort((a, b) {
        final indexA = _desiredDanceOrder.indexOf(a['name']);
        final indexB = _desiredDanceOrder.indexOf(b['name']);
        return (indexA == -1 ? 999 : indexA).compareTo(indexB == -1 ? 999 : indexB);
      });

      if (mounted) {
        setState(() {
          _availableDances = dances.map((d) => d['name'] as String).toList();
          _selectedDance = initialDance != null && _availableDances.contains(initialDance)
              ? initialDance
              : (_availableDances.isNotEmpty ? _availableDances.first : null);
        });
      }
    } catch (e) {
      print("Error loading dances: $e");
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
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final styleName = _selectedStyle!;
      final danceName = _selectedDance!;

      print("🚀 Saving choreography for user: $userId");

      String docId;
      if (widget.docId != null) {
        await FirestoreService.updateChoreography(
          userId: userId,
          choreoDocId: widget.docId!,
          name: _nameController.text,
          styleName: _selectedStyle!,
          danceName: _selectedDance!,
          level: _selectedLevel!,
        );
        docId = widget.docId!;
      } else {
        docId = await FirestoreService.addChoreography(
          name: _nameController.text,
          styleName: styleName,
          danceName: danceName,
          level: _selectedLevel!,
          isPublic: _isPublic,
        );
      }

      print("Choreography saved successfully with ID: $docId");

      if (mounted) {
        setState(() {});

        await Future.delayed(Duration(milliseconds: 300));

        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewChoreographyScreenFirestore(
              choreoDocId: docId,
              styleName: _selectedStyle!,
              danceName: _selectedDance!,
              level: _selectedLevel!,
            ),
          ),
        );
      }
    } catch (e) {
      print("ERROR: Failed to save choreography: $e");
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
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: "Choreography Name"),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _styles.contains(_selectedStyle) ? _selectedStyle : null,
              items: _styles.map((style) {
                return DropdownMenuItem(value: style, child: Text(style));
              }).toList(),
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    _selectedStyle = value;
                    _selectedDance = null;
                    _availableDances = [];
                    _selectedLevel = value?.toLowerCase().contains('country western') ?? false
                        ? _countryWesternLevels.first
                        : _levels.first;
                    if (value != null) {
                      _loadDancesForStyle(value);
                    }
                  });
                }
              },
              decoration: InputDecoration(labelText: "Style"),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _availableDances.contains(_selectedDance) ? _selectedDance : null,
              items: _availableDances.map((dance) {
                return DropdownMenuItem(value: dance, child: Text(dance));
              }).toList(),
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    _selectedDance = value;
                  });
                }
              },
              decoration: InputDecoration(labelText: "Dance"),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: levelsToShow.contains(_selectedLevel) ? _selectedLevel : null,
              items: levelsToShow.map((level) {
                return DropdownMenuItem(value: level, child: Text(level));
              }).toList(),
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    _selectedLevel = value;
                  });
                }
              },
              decoration: InputDecoration(labelText: "Level"),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: _saveChoreography,
                child: Text("Save"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


const _desiredStyleOrder = [
  "International Standard",
  "International Latin",
  "American Smooth",
  "American Rhythm",
  "Country Western",
  "Social Dances"
];

const _desiredDanceOrder = [
  "Waltz", "Tango", "Foxtrot", "Quickstep", "Viennese Waltz",
  "Cha Cha", "Rumba", "Swing", "Mambo", "Bolero", "Samba",
  "Paso Doble", "Jive", "Triple Two", "Nightclub", "Country Waltz",
  "Polka", "Country Cha Cha", "East Coast Swing", "Two Step",
  "West Coast Swing"
];
