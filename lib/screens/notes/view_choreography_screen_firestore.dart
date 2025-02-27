import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../services/firestore_service.dart';
import '../../themes/colors.dart';
import '../learn/move_screen.dart';
import 'add_figure_screen_firestore.dart';

class ViewChoreographyScreenFirestore extends StatefulWidget {
  final String choreoDocId;
  final String styleName;
  final String danceName;
  final String level;

  const ViewChoreographyScreenFirestore({
    required this.choreoDocId,
    required this.styleName,
    required this.danceName,
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
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('choreographies')
                .doc(widget.choreoDocId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return SizedBox.shrink();

              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final bool isPublic = data['isPublic'] == true;

              return isPublic
                  ? IconButton(
                icon: Icon(Icons.share),
                onPressed: () => _showShareCodeDialog(context, widget.choreoDocId),
              )
                  : SizedBox.shrink();
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
              isPublic ? Icons.public : Icons.lock,
              color: isPublic ? Colors.green.shade300 : Colors.red.shade300,
            ),
            SizedBox(width: 8),
            Text(data['name'] ?? "Unnamed Choreography"),
            Spacer(),
            Switch(
              value: isPublic,
              onChanged: (value) => _togglePrivacy(widget.choreoDocId, value),
              activeColor: Colors.green.shade300,
              inactiveThumbColor: Colors.red.shade300,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFiguresList() {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(widget.choreoDocId)
          .collection('figures')
          .orderBy('position')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final figures = snapshot.data!.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          };
        }).toList();

        if (figures.isEmpty) {
          return _buildEmptyChoreographyMessage();
        }

        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          itemCount: figures.length,
          onReorder: (oldIndex, newIndex) => _reorderFigures(figures, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final figure = figures[index];
            return _buildFigureTile(figure, index, Key(figure['id']));
          },
        );
      },
    );
  }

  Widget _buildEmptyChoreographyMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "No figures added yet!",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Tap the + button to add your first figure.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _hasVideo(Map<String, dynamic> figure) {
    final start = figure['start'] ?? 0;
    final end = figure['end'] ?? 0;
    final hasVideoUrl = (figure['video_url'] ?? '').isNotEmpty;
    return hasVideoUrl && start < end;
  }

  void _playVideo(BuildContext context, Map<String, dynamic> figure) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MoveScreen(move: figure),
      ),
    );
  }

  Widget _buildFigureTile(Map<String, dynamic> figure, int index, Key key) {
    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Icon(
              Icons.drag_handle,
              size: 30,
              color: _getLevelColor(figure['level'] ?? 'Custom'),
            ),
          ),
        ),
        title: Text(figure['description'] ?? 'Unnamed'),
        subtitle: (figure['notes'] != null && figure['notes'].isNotEmpty)
            ? Text(figure['notes'], style: Theme.of(context).textTheme.bodySmall)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.play_circle_outline,
                color: _hasVideo(figure)
                    ? AppColors.blueAccent
                    : Colors.grey,
              ),
              onPressed: _hasVideo(figure)
                  ? () => _playVideo(context, figure)
                  : null,
            ),
            IconButton(
              icon: Icon(Icons.edit_note_rounded,
                  color: Theme.of(context).colorScheme.secondary),
              onPressed: () => _editNotes(figure),
            ),
            IconButton(
              icon: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.error),
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

    final userId = FirebaseAuth.instance.currentUser!.uid;

    for (int i = 0; i < figures.length; i++) {
      await FirestoreService.reorderFigures(
        userId: userId,
        choreoId: widget.choreoDocId,
        figureId: figures[i]['id'],
        newPosition: i,
      );
    }
  }

  Future<void> _editNotes(Map<String, dynamic> figure) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(widget.choreoDocId)
        .collection('figures');

    try {
      final querySnapshot = await docRef
          .where('description', isEqualTo: figure['description'])
          .where('video_url', isEqualTo: figure['video_url'])
          .get();

      if (querySnapshot.docs.isEmpty) {
        print("Error: No matching figure found to update.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Figure not found in Firestore.")),
        );
        return;
      }

      final figureDocRef = querySnapshot.docs.first.reference;

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
        await figureDocRef.update({'notes': newNotes});
        print("Notes updated successfully.");
      }

    } catch (e) {
      print("Error updating notes: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update notes: $e")),
      );
    }
  }

  Future<void> _removeFigure(Map<String, dynamic> figure) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    try {
      final figureId = figure['id'];

      await FirestoreService.deleteFigureFromChoreography(
        userId: userId,
        choreoId: widget.choreoDocId,
        figureId: figureId,
      );

      print("Successfully deleted figure: ${figure['description']}");
    } catch (e) {
      print("Error deleting figure: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete figure: $e")),
      );
    }
  }

  void _addFigure() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User not authenticated.");
      return;
    }

    final userId = user.uid;

    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(widget.choreoDocId)
        .get()
        .then((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        final styleName = data['style_name'] ?? 'Unknown Style';
        final danceName = data['dance_name'] ?? 'Unknown Dance';

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddFigureScreenFirestore(
                choreoDocId: widget.choreoDocId,
                styleName: styleName,
                danceName: danceName,
                level: widget.level,
              ),
            ),
          );
        }
      }
    }).catchError((e) {
      print("Error fetching choreography: $e");
    });
  }

  void _showShareCodeDialog(BuildContext context, String choreoId) {
    final shareCode = "CHOREO-$choreoId";

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text("Share Your Choreography"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Share this code:", style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 8),
              SelectableText(
                shareCode,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.highlight),
              ),
              SizedBox(height: 12),
              Text(
                "Other users can enter this code to copy your choreography.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: Theme.of(context).textTheme.titleSmall),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: shareCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Share code copied!")),
                );
                Navigator.pop(ctx);
              },
              icon: Icon(Icons.copy),
              label: Text("Copy Code"),
            ),
          ],
        );
      },
    );
  }

  void _togglePrivacy(String choreoDocId, bool isPublic) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    await FirestoreService.updateChoreographyPrivacy(
      userId: userId,
      choreoDocId: choreoDocId,
      isPublic: isPublic,
    );

    if (isPublic) {
      final userChoreoRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('choreographies')
          .doc(choreoDocId);

      final doc = await userChoreoRef.get();

      if (doc.exists) {
        var data = doc.data()!;
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
        backgroundColor: isPublic ? Colors.green.shade300 : Colors.red.shade300,
      ),
    );
  }
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