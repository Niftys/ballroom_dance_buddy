import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'screens/music/music_screen.dart';
import 'screens/notes/notes_screen.dart';
import 'screens/learn/learn_screen.dart';
import 'screens/notes/view_choreography_screen.dart';
import 'widgets/floating_music_player.dart';
import '/services/database_service.dart';
import 'dart:io';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.initializeDB();
  runApp(BallroomDanceBuddy());
}

class BallroomDanceBuddy extends StatelessWidget {
  final String? fileUri;

  const BallroomDanceBuddy({super.key, this.fileUri});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.purple),
      home: fileUri != null
          ? ImportHandlerScreen(fileUri: fileUri!) // Handle file import
          : const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayerExpanded = false;
  bool _isInFullscreen = false;
  int _selectedIndex = 0;

  void _onSongsReady(List<String> songs) {
    setState(() {});
  }

  void _togglePlayerExpanded(bool isExpanded) {
    setState(() {
      _isPlayerExpanded = isExpanded;
    });
  }

  void _onFullscreenChange(bool isFullscreen) {
    setState(() {
      _isInFullscreen = isFullscreen;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: !_isInFullscreen ? (_isPlayerExpanded ? 180 : 60) : 0,
            ),
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                NotesScreen(),
                MusicScreen(
                  audioPlayer: _audioPlayer,
                  onSongsReady: _onSongsReady,
                ),
                LearnScreen(
                  onFullscreenChange: _onFullscreenChange,
                ),
              ],
            ),
          ),
          if (!_isInFullscreen)
            Align(
              alignment: Alignment.bottomCenter,
              child: FloatingMusicPlayer(
                audioPlayer: _audioPlayer,
                onExpandToggle: _togglePlayerExpanded,
              ),
            ),
        ],
      ),
      bottomNavigationBar: !_isInFullscreen
          ? BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'Choreo'),
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Music'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Learn'),
        ],
      )
          : null,
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

class ImportHandlerScreen extends StatelessWidget {
  final String fileUri;

  ImportHandlerScreen({required this.fileUri});

  Future<void> _handleFile(BuildContext context) async {
    try {
      // Read the file
      final file = File(Uri.parse(fileUri).path);
      final content = await file.readAsString();
      final data = jsonDecode(content);

      // Import choreography into the database
      final choreography = data['choreography'];
      final figures = data['figures'];

      if (choreography == null || figures == null) {
        throw FormatException("Invalid file format");
      }

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
          SnackBar(content: Text("Choreography '${choreography['name']}' imported successfully!")));

      // Navigate to the ViewChoreographyScreen for the imported choreography
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ViewChoreographyScreen(
            choreographyId: choreographyId,
            styleId: choreography['style_id'],
            danceId: choreography['dance_id'],
            level: choreography['level'],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to import choreography: $e")),
      );
      Navigator.pop(context); // Return to the main screen if failed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Importing File...")),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _handleFile(context),
          child: Text("Import Choreography"),
        ),
      ),
    );
  }
}