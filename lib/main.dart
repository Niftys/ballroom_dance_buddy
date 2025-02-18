import 'package:ballroom_dance_buddy/screens/notes/notes_screen_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'services/firestore_service.dart';
import 'screens/music/music_screen.dart';
import 'screens/learn/learn_screen.dart';
import 'widgets/floating_music_player.dart';
import 'themes/light_theme.dart';
import 'themes/dark_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    sqfliteFfiInit(); // Only if you still want sqflite for anything else
  }

  final themeProvider = ThemeProvider();
  await themeProvider.loadThemePreference();
  await themeProvider.loadAutoplayPreference();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: false,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await FirebaseFirestore.instance.disableNetwork();
  await FirebaseFirestore.instance.enableNetwork();

  runApp(
    ChangeNotifierProvider(
      create: (_) => themeProvider,
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
      // If you previously had local DB init, remove or comment out:
      // await DatabaseService.initializeDB();
    } catch (e) {
      if (kDebugMode) {
        print("Database failed to initialize: $e");
      }
    }
  }
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _autoplayEnabled = false;

  ThemeMode get themeMode => _themeMode;
  bool get autoplayEnabled => _autoplayEnabled;

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

  Future<void> loadAutoplayPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _autoplayEnabled = prefs.getBool('autoplayEnabled') ?? false;
    notifyListeners();
  }

  Future<void> toggleAutoplay(bool enabled) async {
    _autoplayEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoplayEnabled', enabled);
    notifyListeners();
  }
}

class BallroomDanceBuddy extends StatelessWidget {
  const BallroomDanceBuddy({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ballroom Dance Buddy',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode,
      initialRoute: FirebaseAuth.instance.currentUser == null ? '/login' : '/mainScreen',
      routes: {
        '/login': (context) => LoginScreen(),
        '/mainScreen': (context) => MainScreen(),  // Ensure this matches your main screen
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<MusicScreenState> _musicScreenKey = GlobalKey();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String _currentSongTitle = "No Song Playing";
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

  void _updateSongTitle(String newTitle) {
    setState(() {
      _currentSongTitle = newTitle;
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
                // Firestore-based notes screen
                NotesScreenFirestore(
                  onOpenSettings: () => _openSettingsPopup(context),
                ),
                // Music screen
                MusicScreen(
                  audioPlayer: _audioPlayer,
                  onSongsReady: _onSongsReady,
                  key: _musicScreenKey,
                  onSongTitleChanged: _updateSongTitle,
                ),
                // Learn screen
                LearnScreen(
                  onFullscreenChange: _onFullscreenChange,
                ),
              ],
            ),
          ),

          // The floating music player on bottom
          if (!_isInFullscreen)
            Align(
              alignment: Alignment.bottomCenter,
              child: FloatingMusicPlayer(
                audioPlayer: _audioPlayer,
                onExpandToggle: _togglePlayerExpanded,
                musicScreenKey: _musicScreenKey,
                onSongTitleChanged: _updateSongTitle,
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
          title: Text("Settings", style: Theme.of(context).textTheme.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dark Mode toggle
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
              // Autoplay toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Autoplay", style: Theme.of(context).textTheme.bodyLarge),
                  Switch(
                    value: themeProvider.autoplayEnabled,
                    onChanged: (bool value) {
                      themeProvider.toggleAutoplay(value);
                    },
                  ),
                ],
              ),
              const Divider(),
              // About
              ListTile(
                leading: Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                title: Text("About App", style: Theme.of(context).textTheme.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomAboutDialog(context);
                },
              ),
              // Donate
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
          title: Text("About Ballroom Dance Buddy", style: Theme.of(context).textTheme.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 60, color: Theme.of(context).primaryColor),
              const SizedBox(height: 16),
              Text("Version: 1.0.0", style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                "This app was developed by an unemployed physics graduate trying to market his coding skills.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "Feel free to reach out to lowerys(at)proton.me with issues.",
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
    const donationUrl =
        "https://www.paypal.com/donate/?business=BA2GYPC746MSQ&no_recurring=0&item_name=Thank+you+for+supporting+Ballroom+Dance+Buddy%21";
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
    // If you want to do Firestore-based import, do it here
    // or remove this entirely if you no longer do local-file imports
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