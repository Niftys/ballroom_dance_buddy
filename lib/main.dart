import 'package:ballroom_dance_buddy/screens/notes/notes_screen_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';
import 'login.dart';
import 'screens/learn/learn_screen.dart';
import 'screens/music/music_screen.dart';
import 'themes/dark_theme.dart';
import 'themes/light_theme.dart';
import 'widgets/floating_music_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  if (!kIsWeb) {
    sqfliteFfiInit();
  }

  final themeProvider = ThemeProvider();
  await themeProvider.loadThemePreference();
  await themeProvider.loadAutoplayPreference();

  runApp(
    ChangeNotifierProvider(
      create: (_) => themeProvider,
      child: const BallroomDanceBuddy(),
    ),
  );
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
      home: AuthWrapper(),
      routes: {
        '/mainScreen': (context) => MainScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          debugPrint("User logged in: ${snapshot.data!.uid}");
          return MainScreen();
        } else {
          debugPrint("No user logged in");
          return LoginScreen();
        }
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
                NotesScreenFirestore(
                  onOpenSettings: () => _openSettingsPopup(context),
                ),
                MusicScreen(
                  audioPlayer: _audioPlayer,
                  onSongsReady: _onSongsReady,
                  key: _musicScreenKey,
                  onSongTitleChanged: _updateSongTitle,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Dark Mode", style: Theme.of(context).textTheme.bodyLarge),
                  StatefulBuilder(
                    builder: (context, setState) {
                      return Switch(
                        value: isDarkMode,
                        onChanged: (bool value) async {
                          Navigator.pop(context);
                          await Future.delayed(Duration(milliseconds: 100));
                          themeProvider.toggleTheme(value);
                        },
                      );
                    },
                  ),
                ],
              ),
              const Divider(),
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
      debugPrint("Could not launch $donationUrl");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}