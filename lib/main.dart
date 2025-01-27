import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/music/music_screen.dart';
import 'screens/notes/notes_screen.dart';
import 'screens/learn/learn_screen.dart';
import 'screens/notes/view_choreography_screen.dart';
import 'widgets/floating_music_player.dart';
import 'services/database_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'themes/light_theme.dart';
import 'themes/dark_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    sqfliteFfiInit();
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const FutureBuilderApp(),
    ),
  );
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
              body: LoadingIndicator(),
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

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  Future<void> loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDarkMode) async {
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    notifyListeners();
  }
}

class BallroomDanceBuddy extends StatelessWidget {
  final String? fileUri;

  const BallroomDanceBuddy({super.key, this.fileUri});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode,
      home: fileUri != null
          ? ImportHandlerScreen(fileUri: fileUri!)
          : MainScreen(),
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
    final themeProvider = Provider.of<ThemeProvider>(context);

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
                NotesScreen(onOpenSettings: () => _openSettingsPopup(context)),
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

  void _openSettingsPopup(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Settings",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Dark Mode", style: Theme.of(context).textTheme.bodyLarge),
                  Switch(
                    value: isDarkMode,
                    onChanged: (bool value) {
                      Navigator.pop(context);
                      themeProvider.toggleTheme(value);
                    },
                  ),
                ],
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                title: Text("About App", style: Theme.of(context).textTheme.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomAboutDialog(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.volunteer_activism, color: Theme.of(context).primaryColor),
                title: Text("Love the app? Consider donating", style: Theme.of(context).textTheme.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _openDonationLink();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close", style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        );
      },
    );
  }

  void _showCustomAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "About Ballroom Dance Buddy",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 60, color: Theme.of(context).primaryColor),
              const SizedBox(height: 16),
              Text(
                "Version: 1.0.0",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                "This app was developed by an unemployed physics graduate trying to market his coding skills.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "With that in mind, if you encounter any issues, feel free to reach out to lowerys(at)proton.me.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "I cannot guarantee perfection, or even competency, but I have and will work hard to improve my little project.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close", style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        );
      },
    );
  }

  void _openDonationLink() async {
    const donationUrl = "https://www.paypal.com/donate/?business=BA2GYPC746MSQ&no_recurring=0&item_name=Thank+you+for+supporting+Ballroom+Dance+Buddy%21+Donations+like+yours+keep+me+from+doing+anything+annoying+to+make+money+%3A%29&currency_code=USD";
    if (await canLaunch(donationUrl)) {
      await launch(donationUrl);
    } else {
      if (kDebugMode) {
        print("Could not launch $donationUrl");
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

class ImportHandlerScreen extends StatelessWidget {
  final String fileUri;

  const ImportHandlerScreen({super.key, required this.fileUri});

  Future<Directory> _getSafeDirectory() async {
    return Directory.systemTemp;
  }

  Future<void> _handleFile(BuildContext context) async {
    try {
      final directory = await _getSafeDirectory();
      final filePath = '${directory.path}/${Uri.parse(fileUri).path.split('/').last}';
      final file = File(filePath);

      if (!file.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File not found. Please check the path and try again.")),
        );
        Navigator.pop(context);
        return;
      }

      final content = await file.readAsString();
      final data = jsonDecode(content);

      final choreography = data['choreography'];
      final figures = data['figures'];

      if (choreography == null || figures == null) {
        throw const FormatException("Invalid file structure. Missing choreography or figures.");
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
        SnackBar(content: Text("Choreography '${choreography['name']}' imported successfully!")),
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
    } on FileSystemException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("File not found. Please check the path and try again.")),
      );
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid file format. Unable to parse JSON.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to import choreography: $e")),
      );
    } finally {
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

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}