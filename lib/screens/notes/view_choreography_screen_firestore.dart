import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_figure_screen_firestore.dart'; // your new figure-adding screen

class ViewChoreographyScreenFirestore extends StatefulWidget {
  final String choreoDocId;
  final int styleId;
  final int danceId;
  final String level;

  const ViewChoreographyScreenFirestore({
    required this.choreoDocId,
    required this.styleId,
    required this.danceId,
    required this.level,
  });

  @override
  _ViewChoreographyScreenFirestoreState createState() => _ViewChoreographyScreenFirestoreState();
}

class _ViewChoreographyScreenFirestoreState extends State<ViewChoreographyScreenFirestore> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildChoreoName(),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _exportChoreography,
          ),
        ],
      ),
      body: _buildFiguresList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFigure,
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildChoreoName() {
    // Listen to the main doc for the name
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('choreographies')
          .doc(widget.choreoDocId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Text("Loading...");
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        return Text(data['name'] ?? "No name");
      },
    );
  }

  Widget _buildFiguresList() {
    // Listen to sub-collection "figures", sorted by 'position'
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('choreographies')
          .doc(widget.choreoDocId)
          .collection('figures')
          .orderBy('position')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text("No figures"));
        }

        // Convert docs to local map for building the reorderable list
        List<Map<String, dynamic>> figures = [];
        for (final doc in docs) {
          final figData = doc.data() as Map<String, dynamic>;
          figData['id'] = doc.id;
          figures.add(figData);
        }

        return ReorderableListView(
          onReorder: (oldIndex, newIndex) => _reorderFigures(figures, oldIndex, newIndex),
          children: [
            for (int i = 0; i < figures.length; i++)
              _buildFigureTile(figures[i], i),
          ],
        );
      },
    );
  }

  Widget _buildFigureTile(Map<String, dynamic> figure, int index) {
    return Card(
      key: ValueKey(figure['id']), // must use a unique key
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: ListTile(
        leading: Icon(Icons.drag_handle),
        title: Text(figure['description'] ?? ''),
        subtitle: (figure['notes'] != null && figure['notes'].isNotEmpty)
            ? Text(figure['notes'])
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_note_rounded),
              onPressed: () => _editNotes(figure),
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _removeFigure(figure),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reorderFigures(List<Map<String, dynamic>> figures, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = figures.removeAt(oldIndex);
    figures.insert(newIndex, item);

    // Now update each figure's 'position' in Firestore
    for (int i = 0; i < figures.length; i++) {
      final figId = figures[i]['id'];
      await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(widget.choreoDocId)
          .collection('figures')
          .doc(figId)
          .update({'position': i});
    }
  }

  Future<void> _editNotes(Map<String, dynamic> figure) async {
    final controller = TextEditingController(text: figure['notes'] ?? '');
    final newNotes = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Notes"),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text("Save")),
        ],
      ),
    );
    if (newNotes != null) {
      // Update the doc
      await FirebaseFirestore.instance
          .collection('choreographies')
          .doc(widget.choreoDocId)
          .collection('figures')
          .doc(figure['id'])
          .update({'notes': newNotes});
    }
  }

  Future<void> _removeFigure(Map<String, dynamic> figure) async {
    await FirebaseFirestore.instance
        .collection('choreographies')
        .doc(widget.choreoDocId)
        .collection('figures')
        .doc(figure['id'])
        .delete();
  }

  void _addFigure() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFigureScreenFirestore(
          choreoDocId: widget.choreoDocId,
          styleId: widget.styleId,
          danceId: widget.danceId,
          level: widget.level,
        ),
      ),
    );
  }

  Future<void> _exportChoreography() async {
    // A quick approach: read doc, read sub-collection, produce JSON, etc.
    // Then share or export
  }
}