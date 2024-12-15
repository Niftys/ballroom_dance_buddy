import 'package:flutter/material.dart';
import '/services/database_service.dart';
import 'view_choreography_screen.dart';
import 'add_choreography_screen.dart';

class NotesScreen extends StatefulWidget {
  @override
  _NotesScreenState createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> _choreographies = [];

  @override
  void initState() {
    super.initState();
    _loadChoreographies();
  }

  Future<void> _loadChoreographies() async {
    try {
      final choreographies = await DatabaseService.getChoreographies();
      setState(() {
        _choreographies = choreographies;
      });
    } catch (e) {
      print("Error loading choreographies: $e");
    }
  }

  void _deleteChoreography(int id) async {
    try {
      await DatabaseService.deleteChoreography(id);
      _loadChoreographies(); // Refresh the list after deletion
    } catch (e) {
      print("Error deleting choreography: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Choreographies")),
      body: _choreographies.isEmpty
          ? Center(child: Text("No choreographies created yet."))
          : ListView.builder(
        itemCount: _choreographies.length,
        itemBuilder: (context, index) {
          final choreo = _choreographies[index];
          return ListTile(
            title: Text(choreo['name']),
            subtitle: Text(
                "${choreo['style_name']} - ${choreo['dance_name']} (${choreo['level']})"),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              color: Colors.red,
              onPressed: () => _deleteChoreography(choreo['id']),
            ),
            onTap: () async {
              try {
                print("Tapped on choreography: ${choreo['name']}");

                // Navigate to the ViewChoreographyScreen
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewChoreographyScreen(
                      choreographyId: choreo['id'],
                      styleId: choreo['style_id'] as int,
                      danceId: choreo['dance_id'] as int,
                      level: choreo['level'] as String,
                    ),
                  ),
                );

                // Refresh data after returning
                if (mounted) {
                  _loadChoreographies();
                }
              } catch (e) {
                print("Error navigating to ViewChoreographyScreen: $e");
              }
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddChoreographyScreen(
                onSave: _loadChoreographies,
              ),
            ),
          );
          // Reload choreographies after adding a new one
          if (result == true) {
            _loadChoreographies();
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
