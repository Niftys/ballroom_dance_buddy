import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../services/firestore_service.dart';
import '../../themes/colors.dart';
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
            onPressed: () {
              final shareCode = widget.choreoDocId; // Use Firestore document ID
              Clipboard.setData(ClipboardData(text: shareCode)); // Copy to clipboard
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Share code copied: $shareCode")),
              );
            },
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
    final userId = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(widget.choreoDocId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text("Error loading choreography");
        }
        if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
          return Text("Choreography Not Found");
        }
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final bool isPublic = data['isPublic'] == true;

        return Row(
          children: [
            Icon(
              isPublic ? Icons.public : Icons.lock, // 🔓 Public, 🔒 Private
              color: isPublic ? Colors.green : Colors.red, // Green for Public, Red for Private
            ),
            SizedBox(width: 8),
            Text(data['name'] ?? "Unnamed Choreography"),
            Spacer(),
            Switch(
              value: isPublic,
              onChanged: (value) => _togglePrivacy(widget.choreoDocId, value),
              activeColor: Colors.green,
              inactiveThumbColor: Colors.red,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFiguresList() {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final isPublicChoreo = // Add logic to check if viewing a public choreo from /choreographies/
    widget.choreoDocId.startsWith('public_'); // Example condition

    final figuresStream = isPublicChoreo
        ? FirebaseFirestore.instance
        .collection('choreographies')
        .doc(widget.choreoDocId)
        .collection('figures')
        .orderBy('position')
        .snapshots()
        : FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(widget.choreoDocId)
        .collection('figures')
        .orderBy('position')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: figuresStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text("Click the plus button to add some figures!"));
        }

        List<Map<String, dynamic>> figures = [];
        for (final doc in docs) {
          final figData = doc.data() as Map<String, dynamic>;
          figData['id'] = doc.id;
          figures.add(figData);
        }

        return ReorderableListView.builder(
          onReorder: (oldIndex, newIndex) => _reorderFigures(figures, oldIndex, newIndex),
          itemCount: figures.length,
          buildDefaultDragHandles: false,
          itemBuilder: (context, index) {
            return _buildFigureTile(figures[index], index);
          },
        );
      },
    );
  }

  Widget _buildFigureTile(Map<String, dynamic> figure, int index) {
    return Card(
      key: ValueKey(figure['id']), // Must use a unique key
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: Icon(
            Icons.drag_handle,
            color: _getLevelColor(figure['level'] ?? ''),
            size: 30,
          ),
        ),
        title: Text(figure['description'] ?? ''),
        subtitle: (figure['notes'] != null && figure['notes'].isNotEmpty)
            ? Text(figure['notes'], style: Theme.of(context).textTheme.titleSmall)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_note_rounded),
              onPressed: () => _editNotes(figure),
              color: Theme.of(context).colorScheme.secondary,
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _removeFigure(figure),
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'bronze':
        return AppColors.bronze;
      case 'silver':
        return AppColors.silver;
      case 'gold':
        return AppColors.gold;
      case 'custom':
        return AppColors.highlight;
      default:
        return AppColors.highlight;
    }
  }

  Future<void> _reorderFigures(List<Map<String, dynamic>> figures, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = figures.removeAt(oldIndex);
    figures.insert(newIndex, item);

    final userId = FirebaseAuth.instance.currentUser!.uid;
    for (int i = 0; i < figures.length; i++) {
      final figId = figures[i]['id'];
      await FirestoreService.reorderFigures(
        userId: userId,
        choreoId: widget.choreoDocId,
        figureId: figId,
        newPosition: i,
      );
    }
  }

  Future<void> _editNotes(Map<String, dynamic> figure) async {
    final controller = TextEditingController(text: figure['notes'] ?? '');

    final newNotes = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Notes"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: "Notes"),
          onSubmitted: (_) => Navigator.pop(ctx, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text("Save"),
          ),
        ],
      ),
    );

    if (newNotes != null) {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      await FirestoreService.updateFigureNotes(
        userId: userId,
        choreoId: widget.choreoDocId,
        figureId: figure['id'],
        newNotes: newNotes,
      );
    }
  }

  Future<void> _removeFigure(Map<String, dynamic> figure) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await FirestoreService.deleteFigureFromChoreography(
      userId: userId,
      choreoId: widget.choreoDocId,
      figureId: figure['id'],
    );
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

  void _togglePrivacy(String choreoDocId, bool isPublic) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    // First update the privacy flag
    await FirestoreService.updateChoreographyPrivacy(
      userId: userId,
      choreoDocId: choreoDocId,
      isPublic: isPublic,
    );

    // If making public, update ownership data
    if (isPublic) {
      final userChoreoRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(choreoDocId);

      final doc = await userChoreoRef.get();

      if (doc.exists) {
        var data = doc.data()!;
        // Ensure created_by matches current user in global collection
        data['created_by'] = userId;

        await FirebaseFirestore.instance
            .collection('choreographies')
            .doc(choreoDocId)
            .set(data);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPublic
            ? "Choreography is now PUBLIC 🔓"
            : "Choreography is now PRIVATE 🔒"),
        backgroundColor: isPublic ? Colors.green : Colors.red,
      ),
    );
  }
}