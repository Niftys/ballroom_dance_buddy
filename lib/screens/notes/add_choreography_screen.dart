import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/services/database_service.dart';
import 'view_choreography_screen.dart';

class AddChoreographyScreen extends StatefulWidget {
  final void Function(int choreographyId, int styleId, int danceId, String level) onSave;
  final int? choreographyId;
  final String? initialName;
  final int? initialStyleId;
  final int? initialDanceId;
  final String? initialLevel;

  AddChoreographyScreen({
    required this.onSave,
    this.choreographyId,
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

  @override
  void initState() {
    super.initState();
    if (widget.choreographyId != null) {
      DatabaseService.getStylesAndDancesFromJson().then((stylesAndDances) {
        _initializeForEditing(stylesAndDances);
      });
    } else {
      _loadStyles();
    }
  }

  Future<void> _loadStyles() async {
    try {
      final stylesAndDances = await DatabaseService
          .getStylesAndDancesFromJson();

      setState(() {
        _styles = stylesAndDances.keys.toList();
        _selectedStyle = _styles.isNotEmpty ? _styles.first : null;
        _availableDances =
        _selectedStyle != null ? stylesAndDances[_selectedStyle!] ?? [] : [];
        _selectedDance =
        _availableDances.isNotEmpty ? _availableDances.first : null;
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

  Future<void> _initializeForEditing(
      Map<String, List<String>> stylesAndDances) async {
    try {
      setState(() {
        _nameController.text = widget.initialName ?? '';
        _selectedLevel = widget.initialLevel ?? _levels.first;
        _styles = stylesAndDances.keys.toList();
      });

      if (widget.initialStyleId != null) {
        final styleName = await DatabaseService.getStyleNameById(
            widget.initialStyleId!);
        setState(() {
          _selectedStyle = styleName;
          _availableDances = stylesAndDances[styleName] ?? [];
        });

        if (widget.initialDanceId != null) {
          final danceName = await DatabaseService.getDanceNameById(
              widget.initialDanceId!);
          setState(() {
            _selectedDance = danceName;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error initializing editor for editing: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to initialize editor")),
      );
    }
  }

  final List<String> _countryWesternLevels = [
    'Newcomer IV',
    'Newcomer III',
    'Newcomer II'
  ];

  Future<void> _loadDancesForStyle(String styleName) async {
    try {
      final stylesAndDances = await DatabaseService
          .getStylesAndDancesFromJson();

      setState(() {
        _availableDances = stylesAndDances[styleName] ?? [];
        _selectedDance =
        _availableDances.isNotEmpty ? _availableDances.first : null;

        // Check if the selected style is Country Western and adjust levels
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
        SnackBar(content: Text("Failed to load dances for the selected style")),
      );
    }
  }

  void _saveChoreography() async {
    if (_nameController.text.isEmpty || _selectedStyle == null ||
        _selectedDance == null || _selectedLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    try {
      final styleId = await DatabaseService.getStyleIdByName(_selectedStyle!);
      final danceId = await DatabaseService.getDanceIdByNameAndStyle(
          _selectedDance!, styleId);

      int choreographyId;

      if (widget.choreographyId != null) {
        // Update existing choreography
        await DatabaseService.updateChoreography(
          id: widget.choreographyId!,
          name: _nameController.text,
          styleId: styleId,
          danceId: danceId,
          level: _selectedLevel!,
        );
        choreographyId = widget.choreographyId!;
        widget.onSave(choreographyId, styleId, danceId, _selectedLevel!);
      } else {
        // Create new choreography
        choreographyId = await DatabaseService.addChoreography(
          name: _nameController.text,
          styleId: styleId,
          danceId: danceId,
          level: _selectedLevel!,
        );
        widget.onSave(choreographyId, styleId, danceId, _selectedLevel!);
      }

      // Replace stack to ensure clean navigation
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ViewChoreographyScreen(
                choreographyId: choreographyId,
                styleId: styleId,
                danceId: danceId,
                level: _selectedLevel!,
              ),
        ),
            (route) => route.isFirst, // Keep only the first screen in the stack
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error saving choreography: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save choreography: ${e.toString()}")),
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
        title: Text(
          widget.choreographyId != null
              ? "Edit Choreography"
              : "Add Choreography",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _styles.isEmpty
          ? Center(child: CircularProgressIndicator(color: Colors.purple))
          : AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: _buildForm(),
      ),
      backgroundColor: Colors.grey.shade100,
    );
  }

  Widget _buildForm() {
    final bool isCountryWestern = _selectedStyle?.toLowerCase().contains(
        'country western') ?? false;
    final List<String> levelsToShow = isCountryWestern
        ? _countryWesternLevels
        : _levels;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: "Choreography Name",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedStyle,
            items: _styles
                .map((style) =>
                DropdownMenuItem(value: style, child: Text(style)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedStyle = value!;
                _loadDancesForStyle(value);
              });
            },
            decoration: InputDecoration(
                labelText: "Style", border: OutlineInputBorder()),
          ),
          SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedDance,
            items: _availableDances
                .map((dance) =>
                DropdownMenuItem(value: dance, child: Text(dance)))
                .toList(),
            onChanged: (value) => setState(() => _selectedDance = value),
            decoration: InputDecoration(
                labelText: "Dance", border: OutlineInputBorder()),
          ),
          SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedLevel,
            items: levelsToShow
                .map((level) =>
                DropdownMenuItem(value: level, child: Text(level)))
                .toList(),
            onChanged: (value) => setState(() => _selectedLevel = value),
            decoration: InputDecoration(
                labelText: "Level", border: OutlineInputBorder()),
          ),
          Spacer(),
          ElevatedButton(
            onPressed: _saveChoreography,
            child: Text("Save"),
          ),
        ],
      ),
    );
  }
}