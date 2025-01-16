import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/services/database_service.dart';
import '/screens/notes/add_choreography_screen.dart';
import '/screens/notes/view_choreography_screen.dart' as ViewScreen;
import 'dart:convert';
import 'package:http/http.dart' as http;

class NotesScreen extends StatefulWidget {
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

  Future<void> _importChoreographyFromLink() async {
    final TextEditingController _linkController = TextEditingController();
    final FocusNode _focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Import Choreography"),
          content: TextField(
            controller: _linkController,
            focusNode: _focusNode, // Attach FocusNode to manage focus
            decoration: InputDecoration(
              labelText: "Paste the link here",
              hintText: "https://example.com",
              border: OutlineInputBorder(),
            ),
            onEditingComplete: () => _focusNode.unfocus(), // Unfocus on completion
            textInputAction: TextInputAction.done,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _focusNode.unfocus(); // Ensure the focus is removed before closing
                Navigator.pop(context);
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final link = _linkController.text.trim();
                if (link.isNotEmpty && Uri.tryParse(link)?.isAbsolute == true) {
                  _focusNode.unfocus(); // Remove focus to avoid keyboard issues
                  Navigator.pop(context);
                  await _downloadAndImportChoreography(link);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please provide a valid link.")),
                  );
                }
              },
              child: Text("Import"),
            ),
          ],
        );
      },
    ).then((_) => _focusNode.dispose()); // Dispose of FocusNode after dialog closes
  }

  Future<void> _downloadAndImportChoreography(String link) async {
    try {
      // Detect Google Drive links and convert to direct API access
      if (link.contains('drive.google.com') && link.contains('/file/d/')) {
        final fileId = RegExp(r'/file/d/([^/]+)').firstMatch(link)?.group(1);
        if (fileId != null) {
          final apiKey = 'AIzaSyBKy5Of6kXTPaWempXXbMSFTu7vylebfUE';
          link = 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media&key=$apiKey';
        } else {
          throw Exception("Invalid Google Drive link format");
        }
      }

      final encodedUrl = Uri.encodeComponent(link); // Encode the link
      final proxyUrl = 'https://us-central1-ballroom-dance-buddy.cloudfunctions.net/proxy?url=$encodedUrl';
      print(proxyUrl);

      // Fetch the JSON file
      final response = await http.get(Uri.parse(proxyUrl));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        // Validate the JSON structure
        final choreography = jsonData['choreography'];
        final figures = jsonData['figures'];

        if (choreography == null || figures == null) {
          throw FormatException("Invalid file format");
        }

        // Add choreography to the database
        final choreographyId = await DatabaseService.addChoreography(
          name: choreography['name'],
          styleId: choreography['style_id'],
          danceId: choreography['dance_id'],
          level: choreography['level'],
        );

        for (var figure in figures) {
          await DatabaseService.addFigureToChoreography(
            choreographyId: choreographyId,
            figureId: figure['id'],
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Choreography imported successfully!")),
        );

        _loadChoreographies();
      } else {
        throw Exception("Failed to fetch file. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching choreography: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to import choreography: $e")),
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
        elevation: 5,
        backgroundColor: Colors.white,
        shadowColor: Colors.black54,
        title: Text(
          "Choreographies",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search choreographies...",
                prefixIcon: Icon(Icons.search, color: Colors.black54),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Colors.deepPurple),
                ),
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
                onPressed: _importChoreographyFromLink, // Import from link functionality
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
      backgroundColor: Colors.grey.shade100,
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
          elevation: 3,
          shadowColor: Colors.black54,
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: ListTile(
            title: Text(choreo['name'], style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${choreo['style_name']} - ${choreo['dance_name']} (${choreo['level']})"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.deepPurple),
                  onPressed: () => _editChoreography(
                    choreo['id'] as int,
                    choreo['name'] as String,
                    choreo['style_id'] as int,
                    choreo['dance_id'] as int,
                    choreo['level'] as String,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red.shade300),
                  onPressed: () => _deleteChoreography(choreo['id'] as int),
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
          elevation: 3,
          shadowColor: Colors.black54,
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: ExpansionTile(
            title: Text(style, style: TextStyle(fontWeight: FontWeight.w400)),
            children: dances.entries.map((danceEntry) {
              final dance = danceEntry.key;
              final choreos = danceEntry.value;

              return ExpansionTile(
                title: Text(dance, style: TextStyle(fontWeight: FontWeight.w400)),
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
                          icon: Icon(Icons.edit, color: Colors.deepPurple),
                          onPressed: () => _editChoreography(
                            choreo['id'] as int,
                            choreo['name'] as String,
                            choreo['style_id'] as int,
                            choreo['dance_id'] as int,
                            choreo['level'] as String,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red.shade300),
                          onPressed: () => _deleteChoreography(choreo['id'] as int),
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
