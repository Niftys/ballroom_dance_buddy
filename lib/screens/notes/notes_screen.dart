import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import '../../main.dart';
import '/services/database_service.dart';
import '/screens/notes/add_choreography_screen.dart';
import '/screens/notes/view_choreography_screen.dart' as ViewScreen;
import 'dart:convert';
import 'dart:io' show File;
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class NotesScreen extends StatefulWidget {
  final VoidCallback? onOpenSettings; // Callback for opening settings

  const NotesScreen({Key? key, this.onOpenSettings}) : super(key: key);

  @override
  _NotesScreenState createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  Map<String, Map<String, List<Map<String, dynamic>>>> _choreographiesByStyleAndDance = {};
  List<Map<String, dynamic>> _searchResults = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadChoreographies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importChoreography(BuildContext context) async {
    final TextEditingController linkController = TextEditingController();
    final FocusNode focusNode = FocusNode();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Center(
                child: Text(
                  "Import Choreography",
                  style: Theme.of(context).textTheme.titleLarge
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _importChoreographyFromFile(); // Handle file picker import
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                      ),
                      child: Text("Import from File"),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "OR",
                      style: Theme.of(context).textTheme.titleMedium
                    ),
                    SizedBox(height: 16),
                    TextField(
                      textAlign: TextAlign.center,
                      controller: linkController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: "Import from link",
                        contentPadding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0), // Adjust padding
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).primaryColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Align buttons
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Cancel",
                        style: Theme.of(context).textTheme.titleSmall
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final link = linkController.text.trim();
                        if (link.isNotEmpty && Uri.tryParse(link)?.isAbsolute == true) {
                          Navigator.pop(context);
                          await _downloadAndImportChoreography(link); // Handle link import
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Please provide a valid link.")),
                          );
                        }
                      },
                      child: Text("Import"),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> fetchApiKey() async {
    final response = await http.get(Uri.parse('https://<YOUR_PROJECT>.web.app/getEnvConfig'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['apiKey'];
    } else {
      throw Exception("Failed to load API key");
    }
  }

  Future<void> _downloadAndImportChoreography(String link) async {
    try {
      if (link.isEmpty || !Uri.tryParse(link)!.isAbsolute) {
        throw Exception("Invalid link provided.");
      }

      // Extract the fileId from the Google Drive link
      if (link.contains("drive.google.com")) {
        final fileId = RegExp(r'/file/d/([^/]+)').firstMatch(link)?.group(1);
        if (fileId != null) {
          // Firebase function URL
          link = "https://us-central1-ballroom-dance-buddy.cloudfunctions.net/fetchGoogleDriveFile?fileId=$fileId";
        } else {
          throw Exception("Invalid Google Drive link format.");
        }
      }

      // Display a loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Call the Firebase function to fetch the file
      final response = await http.get(Uri.parse(link));

      if (response.statusCode == 200) {
        // Process the JSON content
        await _processImportedJson(response.body, context);
      } else {
        throw Exception("Failed to fetch file. Status code: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to import choreography: $e")),
      );
    } finally {
      Navigator.pop(context); // Dismiss the loading indicator
    }
  }


  Future<void> _importChoreographyFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'choreo'],
      );

      if (result != null) {
        final fileBytes = kIsWeb ? result.files.first.bytes : File(result.files.single.path!).readAsBytesSync();
        if (fileBytes == null) throw Exception("File content is empty.");

        final content = utf8.decode(fileBytes);
        await _processImportedJson(content, context);
      } else {
        print("No file selected");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to import choreography: $e")),
      );
    }
  }

  Future<void> _processImportedJson(String content, BuildContext context) async {
    try {
      final data = jsonDecode(content);
      if (data is! Map || !data.containsKey('choreography') || !data.containsKey('figures')) {
        throw FormatException("Invalid JSON structure.");
      }

      final choreography = data['choreography'];
      final figures = data['figures'] as List;

      if (choreography == null || figures.isEmpty) {
        throw FormatException("Missing required data: choreography or figures.");
      }

      final choreographyId = await DatabaseService.addChoreography(
        name: choreography['name'],
        styleId: choreography['style_id'],
        danceId: choreography['dance_id'],
        level: choreography['level'],
      );

      for (final figure in figures) {
        await DatabaseService.addFigureToChoreography(
          choreographyId: choreographyId,
          figureId: figure['id'],
          notes: figure['notes'] ?? '',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Choreography '${choreography['name']}' imported successfully!")),
      );
      await _loadChoreographies();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error processing file: $e")),
      );
    }
  }

  Future<void> _loadChoreographies() async {
    try {
      final stylesAndDances = await DatabaseService.getStylesAndDancesFromJson();
      Map<String, Map<String, List<Map<String, dynamic>>>> organizedChoreographies = {};

      stylesAndDances.forEach((style, dances) {
        organizedChoreographies[style] = {};
        for (var dance in dances) {
          organizedChoreographies[style]![dance] = [];
        }
      });

      final choreographies = await DatabaseService.getChoreographies();

      for (var choreo in choreographies) {
        final style = choreo['style_name'] as String;
        final dance = choreo['dance_name'] as String;

        if (organizedChoreographies.containsKey(style) &&
            organizedChoreographies[style]!.containsKey(dance)) {
          organizedChoreographies[style]![dance]!.add(choreo);
        }
      }

      setState(() {
        _choreographiesByStyleAndDance = organizedChoreographies;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error loading choreographies: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load data.")),
      );
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
      });
      return;
    }

    List<Map<String, dynamic>> results = [];
    _choreographiesByStyleAndDance.forEach((style, dances) {
      dances.forEach((dance, choreos) {
        for (var choreo in choreos) {
          final name = (choreo['name'] as String).toLowerCase();
          final level = (choreo['level'] as String).toLowerCase();
          final styleName = (choreo['style_name'] as String).toLowerCase();
          final danceName = (choreo['dance_name'] as String).toLowerCase();

          // Check if query matches any field
          if (name.contains(query) ||
              level.contains(query) ||
              styleName.contains(query) ||
              danceName.contains(query)) {
            results.add(choreo);
          }
        }
      });
    });

    setState(() {
      _searchQuery = query;
      _searchResults = results;
    });
  }

  void _deleteChoreography(int id) async {
    try {
      await DatabaseService.deleteChoreography(id);
      _loadChoreographies();
    } catch (e) {
      if (kDebugMode) {
        print("Error deleting choreography: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete choreography.")),
      );
    }
  }

  void _navigateToViewChoreography(int choreographyId, int styleId, int danceId, String level) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewScreen.ViewChoreographyScreen(
          choreographyId: choreographyId,
          styleId: styleId,
          danceId: danceId,
          level: level,
        ),
      ),
    );
  }

  void _addChoreography() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddChoreographyScreen(
          onSave: (choreographyId, styleId, danceId, level) {
            _loadChoreographies(); // Call this function after saving
            _navigateToViewChoreography(choreographyId, styleId, danceId, level);
          },
        ),
      ),
    );

    if (result == true) {
      _loadChoreographies(); // Reload choreographies if the user saves and navigates back
    }
  }

  void _viewChoreography(int id, int styleId, int danceId, String level) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewScreen.ViewChoreographyScreen(
          choreographyId: id,
          styleId: styleId,
          danceId: danceId,
          level: level,
        ),
      ),
    );
  }

  void _editChoreography(int id, String name, int styleId, int danceId, String level) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddChoreographyScreen(
          onSave: (choreographyId, styleId, danceId, level) {
            _loadChoreographies(); // Reload the choreographies
            _navigateToViewChoreography(choreographyId, styleId, danceId, level); // Navigate to the saved choreography
          },
          choreographyId: id,
          initialName: name,
          initialStyleId: styleId,
          initialDanceId: danceId,
          initialLevel: level,
        ),
      ),
    );

    if (result == true) {
      _loadChoreographies();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Choreographies",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: widget.onOpenSettings, // Use the callback
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search choreographies...",
                prefixIcon: Icon(Icons.search),
                filled: true
              ),
            ),
          ),
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResultsWithActions()
                : _buildChoreographyListWithActions(),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Stack(
        children: [
          // Import Choreography Button
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 16),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FloatingActionButton(
                heroTag: "importChoreography",
                onPressed: () => _importChoreography(context), // Wrap it in a closure to pass context
                child: Icon(Icons.link), // Icon for importing
              ),
            ),
          ),
          // Add Choreography Button
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 16),
            child: Align(
              alignment: Alignment.bottomRight,
              child: FloatingActionButton(
                heroTag: "addChoreography",
                onPressed: _addChoreography, // Add new choreography functionality
                child: Icon(Icons.add), // Icon for adding
              ),
            ),
          ),
        ],
      ),
      // backgroundColor: Colors.grey.shade100,
    );
  }

  Widget _buildSearchResultsWithActions() {
    if (_searchResults.isEmpty) {
      return Center(child: Text("No results found."));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final choreo = _searchResults[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: ListTile(
            title: Text(choreo['name'], style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text("${choreo['style_name']} - ${choreo['dance_name']} (${choreo['level']})",
              style: Theme.of(context).textTheme.titleSmall),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.secondary),
                  onPressed: () => _editChoreography(
                    choreo['id'] as int,
                    choreo['name'] as String,
                    choreo['style_id'] as int,
                    choreo['dance_id'] as int,
                    choreo['level'] as String,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("Confirm Deletion"),
                          content: Text("Are you sure you want to delete this choreography? This action cannot be undone."),
                          actions: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Spread buttons apart
                              children: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context, false); // User cancels
                                  },
                                  child: Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context, true); // User confirms
                                  },
                                  child: Text(
                                    "Delete",
                                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmed == true) {
                      _deleteChoreography(choreo['id'] as int); // Perform deletion if confirmed
                    }
                  },
                ),
              ],
            ),
            onTap: () => _viewChoreography(
              choreo['id'] as int,
              choreo['style_id'] as int,
              choreo['dance_id'] as int,
              choreo['level'] as String,
            ),
          ),
        );
      },
    );
  }

  Widget _buildChoreographyListWithActions() {
    return ListView(
      children: _choreographiesByStyleAndDance.entries.map((styleEntry) {
        final style = styleEntry.key;
        final dances = styleEntry.value;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: ExpansionTile(
            title: Text(style),
            children: dances.entries.map((danceEntry) {
              final dance = danceEntry.key;
              final choreos = danceEntry.value;

              return ExpansionTile(
                title: Text(dance),
                children: choreos.isEmpty
                    ? [ListTile(title: Text("No choreographies available."))]
                    : choreos.map((choreo) {
                  return ListTile(
                    title: Text(choreo['name']),
                    subtitle: Text("Level: ${choreo['level']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.secondary),
                          onPressed: () => _editChoreography(
                            choreo['id'] as int,
                            choreo['name'] as String,
                            choreo['style_id'] as int,
                            choreo['dance_id'] as int,
                            choreo['level'] as String,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text("Confirm Deletion"),
                                  content: Text("Are you sure you want to delete this choreography? This action cannot be undone."),
                                  actions: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Spread buttons apart
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context, false); // User cancels
                                          },
                                          child: Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context, true); // User confirms
                                          },
                                          child: Text(
                                            "Delete",
                                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirmed == true) {
                              _deleteChoreography(choreo['id'] as int); // Perform deletion if confirmed
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () => _viewChoreography(
                      choreo['id'] as int,
                      choreo['style_id'] as int,
                      choreo['dance_id'] as int,
                      choreo['level'] as String,
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
