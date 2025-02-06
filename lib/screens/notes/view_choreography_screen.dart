import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../themes/colors.dart';
import '/services/database_service.dart';
import 'add_figure_screen.dart';
import 'dart:convert';
import 'dart:io';
import '/screens/learn/move_screen.dart';
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
      final jsonString = jsonEncode(exportData);

      if (kIsWeb) {
        // Web-specific logic: Create a downloadable file in the browser
        final blob = html.Blob([jsonString], 'application/json');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = "${_choreographyName ?? 'choreography'}.choreo"
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile/Desktop logic
        final directory = await getExternalStorageDirectory();
        if (directory == null) throw Exception("Failed to access storage directory.");

        final filePath = '${directory.path}/${_choreographyName ?? "choreography"}.choreo';
        final file = File(filePath);
        await file.writeAsString(jsonString);

        final xFile = XFile(filePath);
        await Share.shareXFiles([xFile], text: 'Check out my choreography!');
      }
    } catch (e) {
      if (kDebugMode) {
        print("Export error: $e");
      }
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

      if (kDebugMode) {
        print("Figures loaded: ${figures.length}");
      }
      for (var figure in figures) {
        if (kDebugMode) {
          print("Loaded figure: ${figure['description']} with ID: ${figure['choreography_figure_id']} and notes: ${figure['notes']}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error loading figures: $e");
      }
    }
  }

  void _playVideo(Map<String, dynamic> figure) {
    final String? videoUrl = figure['video_url'];
    if (videoUrl == null || videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No video available for this move.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoveScreen(move: figure),  // Pass figure to MoveScreen
      ),
    );
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
      // Update the positions in the database
      for (int i = 0; i < _figures.length; i++) {
        await DatabaseService.updateFigureOrder(
          choreographyFigureId: _figures[i]['choreography_figure_id'],
          newPosition: i,
        );
      }
      if (kDebugMode) {
        print("Figure order updated successfully.");
      }

      // Explicitly reload figures from the database
      await _loadFigures();
    } catch (e) {
      if (kDebugMode) {
        print("Error updating figure order in the database: $e");
      }
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
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text("Cancel", style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _notesController.text),
              child: Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (updatedNotes != null) {
      try {
        if (kDebugMode) {
          print("Updating notes for: $choreographyFigureId");
        }
        await DatabaseService.updateFigureNotes(choreographyFigureId, updatedNotes);
        await _loadFigures();  // Force re-fetch after updating notes
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Notes updated successfully.")),
        );
      } catch (e) {
        if (kDebugMode) {
          print("Error updating notes: $e");
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save notes.")),
        );
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
      _loadFigures();  // Refresh to reflect the newly added figure with choreography_figure_id
    }
  }

  void _removeFigure(int choreographyFigureId) async {
    try {
      await DatabaseService.removeFigureFromChoreography(
        choreographyFigureId: choreographyFigureId,
      );
      _loadFigures();  // Refresh the list after removing the figure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Figure removed from choreography.")),
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error removing figure: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete figure.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _choreographyName ?? "Loading...",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              if (kDebugMode) {
                print("Share button clicked");
              } // Debug log
              _exportChoreography(); // Call the function
            },
          ),
        ],
      ),
      body: _figures.isEmpty
          ? Center(
        child: Text(
          "No figures",
          style: Theme.of(context).textTheme.titleMedium,
        ),
      )
          : ReorderableListView(
        buildDefaultDragHandles: false, // Disable default drag handles
        onReorder: reorderFigures,
        children: _figures.map((figure) {
          final levelColor = figure['level'] == 'Bronze'
              ? AppColors.bronze
              : figure['level'] == 'Silver'
              ? AppColors.silver
              : figure['level'] == 'Gold'
              ? AppColors.gold
              : Theme.of(context).primaryColor;

          return Card(
            key: ValueKey(figure['choreography_figure_id']),
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: ListTile(
              title: Text(
                figure['description'],
                textAlign: figure['notes'] == null || figure['notes']!.isEmpty
                    ? TextAlign.left
                    : TextAlign.start,
                style: Theme.of(context).textTheme.titleMedium
              ),
              subtitle: figure['notes'] != null && figure['notes']!.isNotEmpty
                  ? Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  figure['notes']!,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              )
                  : null,
              leading: ReorderableDragStartListener(
                index: _figures.indexOf(figure),
                child: Icon(Icons.drag_handle, color: levelColor), // Drag handle
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      figure['video_url'] != null
                          ? Icons.play_circle_outline
                          : Icons.block,
                      color: figure['video_url'] != null
                          ? AppColors.blueAccent
                          : Colors.grey,
                    ),
                    onPressed: figure['video_url'] != null
                        ? () => _playVideo(figure)
                        : null,
                    tooltip: figure['video_url'] != null
                        ? 'Play Video'
                        : 'No Video Available',
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_note_rounded, color: Theme.of(context).colorScheme.secondary),
                    onPressed: () => _editNotes(
                      figure['choreography_figure_id'],
                      figure['notes'] ?? "",
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                    onPressed: () => _removeFigure(figure['choreography_figure_id']),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFigure,
        child: Icon(Icons.add),
      ),
    );
  }
}