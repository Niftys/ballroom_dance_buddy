import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import '/services/database_service.dart';
import '/screens/notes/add_choreography_screen.dart';
import '/screens/notes/view_choreography_screen.dart' as ViewScreen;
import 'dart:convert';
import 'dart:io' show File;
import 'dart:async';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

    if (kIsWeb) {
      _initializeDragAndDrop();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importChoreography(BuildContext context) async {
    final TextEditingController _linkController = TextEditingController();
    final FocusNode _focusNode = FocusNode();
    bool isDragging = false;
    bool isDialogOpen = true;
    String dragAndDropMessage = "Drop a .choreo file here";

    // Add event listeners for drag-and-drop if on web
    void _onDragOver(html.Event event) {
      event.preventDefault();
      if (!isDialogOpen) return;
      isDragging = true;
      dragAndDropMessage = "Drop your file here!";
    }

    void _onDragLeave(html.Event event) {
      if (!isDialogOpen) return;
      isDragging = false;
      dragAndDropMessage = "Drop a .choreo file here";
    }

    void _onDrop(html.Event event) {
      event.preventDefault();
      if (!isDialogOpen) return;

      isDragging = false;
      final dataTransfer = (event as html.MouseEvent).dataTransfer;
      if (dataTransfer?.files?.isNotEmpty ?? false) {
        final file = dataTransfer!.files!.first;
        if (file.name.endsWith('.json') || file.name.endsWith('.choreo')) {
          _readFileAsString(file).then((content) => _processImportedJson(content, context));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Invalid file type. Only .json or .choreo allowed.")),
          );
        }
      }
    }

    // Initialize drag-and-drop listeners if web
    if (kIsWeb) {
      html.window.addEventListener('dragover', _onDragOver);
      html.window.addEventListener('dragleave', _onDragLeave);
      html.window.addEventListener('drop', _onDrop);
    }

    // Show the import dialog
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Import Choreography"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (kIsWeb)
                    Container(
                      key: Key('drop-zone'),
                      height: 120,
                      margin: EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isDragging ? Colors.lightBlueAccent : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDragging ? Colors.blue : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          dragAndDropMessage,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDragging ? Colors.blue.shade900 : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  TextField(
                    controller: _linkController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      labelText: "Paste the link here",
                      border: OutlineInputBorder(),
                    ),
                    onEditingComplete: () => _focusNode.unfocus(),
                    textInputAction: TextInputAction.done,
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _importChoreographyFromFile(); // Handle file picker import
                    },
                    child: Text("Import from File"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _focusNode.unfocus();
                    Navigator.pop(context);
                  },
                  child: Text("Cancel"),
                ),
                TextButton(
                  onPressed: () async {
                    _focusNode.unfocus();
                    final link = _linkController.text.trim();
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
            );
          },
        );
      },
    );

    // Cleanup event listeners
    if (kIsWeb) {
      html.window.removeEventListener('dragover', _onDragOver);
      html.window.removeEventListener('dragleave', _onDragLeave);
      html.window.removeEventListener('drop', _onDrop);
    }
  }

  Future<void> _downloadAndImportChoreography(String link) async {
    String apiKey = dotenv.env['API_KEY'] ?? '';
    try {
      if (link.isEmpty || !Uri.tryParse(link)!.isAbsolute) {
        throw Exception("Invalid link provided.");
      }

      // If the link is a Google Drive link, transform it into a Google Drive API link
      if (link.contains("drive.google.com")) {
        final fileId = RegExp(r'/file/d/([^/]+)').firstMatch(link)?.group(1);
        if (fileId != null) {
          link = "https://www.googleapis.com/drive/v3/files/$fileId?alt=media&key=$apiKey";
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

      // Fetch the file content from the provided link
      final response = await http.get(Uri.parse(link));

      if (response.statusCode == 200) {
        // Process the JSON content
        await _processImportedJson(response.body, context);
      } else if (response.statusCode == 404) {
        throw Exception("File is private. Status code: ${response.statusCode}");
      }  else {
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

  void _initializeDragAndDrop() {
    final dropZone = html.document.getElementById('drop-zone');

    if (dropZone != null) {
      // Define listener callbacks
      final dragOver = (html.Event event) {
        event.preventDefault();
        dropZone.style.backgroundColor = "lightblue"; // Highlight drop zone
      };

      final dragLeave = (html.Event event) {
        event.preventDefault();
        dropZone.style.backgroundColor = "transparent"; // Reset highlight
      };

      final drop = (html.Event event) async {
        event.preventDefault();
        dropZone.style.backgroundColor = "transparent";

        final dataTransfer = (event as html.MouseEvent).dataTransfer;
        if (dataTransfer.files?.isNotEmpty ?? false) {
          final file = dataTransfer.files!.first;
          if (file.name.endsWith('.json') || file.name.endsWith('.choreo')) {
            final content = await _readFileAsString(file);
            await _processImportedJson(content, context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Invalid file type. Only .json or .choreo allowed.")),
            );
          }
        }
      };

      // Add listeners
      dropZone.addEventListener('dragover', dragOver);
      dropZone.addEventListener('dragleave', dragLeave);
      dropZone.addEventListener('drop', drop);

      // Ensure listeners are cleaned up when widget is disposed
      ModalRoute.of(context)?.addScopedWillPopCallback(() {
        dropZone.removeEventListener('dragover', dragOver);
        dropZone.removeEventListener('dragleave', dragLeave);
        dropZone.removeEventListener('drop', drop);
        return Future.value(true);
      });
    }
  }

  Future<String> _readFileAsString(html.File file) async {
    final reader = html.FileReader();
    final completer = Completer<String>();

    reader.onLoadEnd.listen((_) => completer.complete(reader.result as String));
    reader.onError.listen((error) => completer.completeError(error));

    reader.readAsText(file);

    return completer.future;
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
