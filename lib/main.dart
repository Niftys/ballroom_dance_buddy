import 'package:flutter/foundation.dart';
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
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FutureBuilderApp());
}

class FutureBuilderApp extends StatelessWidget {
  const FutureBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const BallroomDanceBuddy();
        } else {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
      },
    );
  }

  Future<void> _initializeApp() async {
    try {
      await DatabaseService.initializeDB();
    } catch (e) {
      if (kDebugMode) {
        print("Database failed to initialize: $e");
      }
    }
  }
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
          BottomNavigationBarItem(
              icon: Icon(Icons.note), label: 'Choreo'),
          BottomNavigationBarItem(
              icon: Icon(Icons.music_note), label: 'Music'),
          BottomNavigationBarItem(
              icon: Icon(Icons.school), label: 'Learn'),
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

  Future<Directory> _getSafeDirectory() async {
    if (Platform.isIOS) {
      return Directory.systemTemp;
    }
    return getApplicationDocumentsDirectory();
  }


  // Modify _handleFile to use safe directory loading
  Future<void> _handleFile(BuildContext context) async {
    try {
      // Lazy load directory only when necessary
      final directory = await _getSafeDirectory();
      final filePath =
          '${directory.path}/${Uri.parse(fileUri).path.split('/').last}';
      final file = File(filePath);

      if (!file.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("File not found. Please check the path and try again.")),
        );
        Navigator.pop(context); // Go back if file is missing
        return;
      }

      final content = await file.readAsString();

      late final dynamic data;
      try {
        data = jsonDecode(content);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Invalid file format. Unable to parse JSON.")),
        );
        Navigator.pop(context);
        return;
      }

      final choreography = data['choreography'];
      final figures = data['figures'];

      if (choreography == null || figures == null) {
        throw const FormatException(
            "Invalid file structure. Missing choreography or figures.");
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
        SnackBar(
            content: Text(
                "Choreography '${choreography['name']}' imported successfully!")),
      );

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
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Importing File...")),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _handleFile(context),
          child: const Text("Import Choreography"),
        ),
      ),
    );
  }
}