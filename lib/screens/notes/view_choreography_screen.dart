import 'package:flutter/material.dart';
import '/services/database_service.dart';
import 'add_figure_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

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
  String? _choreographyName;

  @override
  void initState() {
    super.initState();
    _loadChoreographyDetails();
  }

  Future<void> _loadChoreographyDetails() async {
    try {
      final choreography = await DatabaseService.getChoreographyById(widget.choreographyId);
      final figures = await DatabaseService.getFiguresForChoreography(widget.choreographyId);
      setState(() {
        _choreographyName = choreography['name'];
        _figures = figures;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load choreography details.")),
      );
    }
  }

  Future<void> _exportChoreography() async {
    final exportData = {
      'choreography': {
        'name': _choreographyName,
        'style_id': widget.styleId,
        'dance_id': widget.danceId,
        'level': widget.level,
      },
      'figures': _figures,
    };

    try {
      // Save JSON file locally
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${_choreographyName ?? "choreography"}.json';
      final file = File(filePath);
      await file.writeAsString(jsonEncode(exportData));

      if (!file.existsSync()) {
        throw Exception("File does not exist at path: $filePath");
      }

      // Upload file to File.io with expiration and multiple downloads
      final url = Uri.parse("https://file.io?expires=14d"); // Set expiration and max downloads
      final request = http.MultipartRequest("POST", url)
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);
        final shareableLink = data['link']; // File.io returns a 'link' field

        print("Upload successful: $shareableLink. This link will expire after 14 days or one use.");

        // Share the link
        await Share.share("Check my new choreography, ${_choreographyName}! Copy this link into your app: $shareableLink");
      } else {
        print("Response code: ${response.statusCode}");
        print("Response reason: ${response.reasonPhrase}");
        throw Exception("Failed to upload choreography. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Export error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to export choreography: $e")),
      );
    }
  }

  Future<void> _loadFigures() async {
    try {
      final figures = await DatabaseService.getFiguresForChoreography(widget.choreographyId);
      setState(() {
        _figures = figures;
      });
    } catch (e) {
      print("Error loading figures: $e");
    }
  }

  void reorderFigures(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;

    final modifiableFigures = List<Map<String, dynamic>>.from(_figures);

    setState(() {
      final figure = modifiableFigures.removeAt(oldIndex);
      modifiableFigures.insert(newIndex, figure);
      _figures = modifiableFigures;
    });

    try {
      for (int i = 0; i < _figures.length; i++) {
        await DatabaseService.updateFigureOrder(
          choreographyFigureId: _figures[i]['choreography_figure_id'],
          newPosition: i,
        );
      }
      print("Figure order updated successfully.");
    } catch (e) {
      print("Error updating figure order in the database: $e");
      await _loadFigures();
    }
  }

  void _editNotes(int choreographyFigureId, String currentNotes) async {
    final TextEditingController _notesController =
    TextEditingController(text: currentNotes);

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null), // Cancel
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _notesController.text),
                  child: Text(
                    "Save",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (updatedNotes != null) {
      try {
        await DatabaseService.updateFigureNotes(choreographyFigureId, updatedNotes);
        _loadFigures();
      } catch (e) {
        print("Error updating notes: $e");
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

  void _removeFigure(int choreographyFigureId) async {
    try {
      await DatabaseService.removeFigureFromChoreography(
        choreographyFigureId: choreographyFigureId,
      );
      _loadFigures();
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
      appBar: AppBar(
        elevation: 6,
        backgroundColor: Colors.white,
        shadowColor: Colors.black26,
        title: Text(
          _choreographyName ?? "Loading...",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              print("Share button clicked"); // Debug log
              _exportChoreography(); // Call the function
            },
          ),
        ],
      ),
      body: _figures.isEmpty
          ? Center(
              child: Text(
                "No figures",
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          : ReorderableListView(
        onReorder: reorderFigures,
        children: _figures.map((figure) {
          final levelColor = figure['level'] == 'Bronze'
              ? Colors.brown
              : figure['level'] == 'Silver'
              ? Colors.grey
              : figure['level'] == 'Gold'
              ? Colors.amber
              : Colors.deepPurple;

          return Card(
            key: ValueKey(figure['choreography_figure_id']),
            elevation: 3,
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: ListTile(
              title: Text(
                figure['description'],
                textAlign: figure['notes'] == null || figure['notes']!.isEmpty
                    ? TextAlign.left
                    : TextAlign.start,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
              ),
              subtitle: figure['notes'] != null && figure['notes']!.isNotEmpty
                  ? Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  figure['notes']!,
                  style: TextStyle(color: Colors.black54),
                ),
              )
                  : null,
              leading: Icon(Icons.drag_handle, color: levelColor),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_note_rounded, color: Colors.deepPurple),
                    onPressed: () => _editNotes(
                      figure['choreography_figure_id'],
                      figure['notes'] ?? "",
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeFigure(figure['choreography_figure_id']),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purple.shade100,
        onPressed: _addFigure,
        child: Icon(Icons.add, color: Colors.deepPurple),
      ),
    );
  }
}