import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';

class MusicScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final ValueChanged<List<String>> onSongsReady;

  MusicScreen({required this.audioPlayer, required this.onSongsReady});

  @override
  _MusicScreenState createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  Map<String, dynamic> _musicData = {};
  Map<String, List<String>> _styles = {};
  String? _selectedStyle;
  String? _selectedGenre;
  List<String> _currentGenreSongs = [];
  List<String> _customSongs = [];
  Map<String, Uint8List> _webCustomSongs = {};

  @override
  void initState() {
    super.initState();
    _loadMusicData();
  }

  Future<void> _loadMusicData() async {
    final jsonString = await rootBundle.loadString('assets/music-files.json');
    final parsedData = json.decode(jsonString);
    final Map<String, List<String>> styles = {};
    parsedData.forEach((genre, songs) {
      final style = genreToStyleMapping[genre.toLowerCase()] ?? "Other";
      if (!styles.containsKey(style)) {
        styles[style] = [];
      }
      styles[style]!.add(genre);
    });

    setState(() {
      _musicData = parsedData;
      _styles = styles;
    });
  }

  Future<Directory> _getGenreSpecificCustomSongsDirectory(String genre) async {
    final directory = await getApplicationDocumentsDirectory();
    final customSongsDir = Directory('${directory.path}/CustomSongs/$genre');
    if (!await customSongsDir.exists()) {
      await customSongsDir.create(recursive: true);
    }
    return customSongsDir;
  }

  Future<void> _loadCustomSongsForGenre(String genre) async {
    if (kIsWeb) {
      // Web-specific: Do nothing as files are stored in memory
      return;
    }

    final directory = await _getGenreSpecificCustomSongsDirectory(genre);
    final files = directory.listSync().where((file) => file.path.endsWith('.mp3'));
    setState(() {
      _customSongs = files.map((file) => file.path).toList();
    });
  }

  Future<void> _addCustomSongToGenre(String genre) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.isNotEmpty) {
      if (kIsWeb) {
        final fileBytes = result.files.first.bytes;
        final fileName = result.files.first.name;
        if (fileBytes != null) {
          print("Web: Added $fileName with ${fileBytes.lengthInBytes} bytes");
          setState(() {
            _webCustomSongs[fileName] = fileBytes;
          });
        } else {
          print("Web: No file bytes found for $fileName");
        }
      } else {
        final file = File(result.files.first.path!);
        print("Mobile: Adding ${file.path}");
        final directory = await _getGenreSpecificCustomSongsDirectory(genre);
        final newFile = await file.copy('${directory.path}/${file.uri.pathSegments.last}');
        setState(() {
          _customSongs.add(newFile.path);
        });
      }
    } else {
      print("No file selected");
    }
  }

  Future<void> _removeCustomSong(String songPath) async {
    if (kIsWeb) {
      // Web-specific: Remove from in-memory map
      setState(() {
        _webCustomSongs.remove(songPath);
      });
    } else {
      try {
        final file = File(songPath);
        if (await file.exists()) {
          await file.delete();
        }
        setState(() {
          _customSongs.remove(songPath);
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to remove song: $e")),
        );
      }
    }
  }

  void _playSong(String songUrl) {
    if (kIsWeb && _webCustomSongs.containsKey(songUrl)) {
      print("Playing song from memory: $songUrl");
      final songBytes = _webCustomSongs[songUrl]!;
      widget.audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.dataFromBytes(songBytes, mimeType: 'audio/mpeg'),
          tag: songUrl,
        ),
      ).then((_) => widget.audioPlayer.play());
    } else {
      print("Playing song from path: $songUrl");
      final cleanName = _cleanSongName(songUrl);
      widget.audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(songUrl), tag: cleanName),
      ).then((_) => widget.audioPlayer.play());
    }
  }

  String _cleanSongName(String url) {
    final decodedUrl = Uri.decodeFull(url);
    return decodedUrl.split('/').last.replaceAll('.mp3', '').replaceAll('_', '\'');
  }

  void _selectGenre(String genre) {
    setState(() {
      _selectedGenre = genre;
      _currentGenreSongs = List<String>.from(_musicData[genre] ?? []);
      _loadCustomSongsForGenre(genre);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedStyle == null
              ? "Song Player"
              : _selectedGenre == null
              ? "Select Dance"
              : _getFolderDisplayName(_selectedGenre!),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        leading: _selectedStyle != null
            ? IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              if (_selectedGenre != null) {
                _selectedGenre = null;
              } else {
                _selectedStyle = null;
              }
            });
          },
        )
            : null,
        actions: _selectedGenre != null
            ? [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _addCustomSongToGenre(_selectedGenre!),
          )
        ]
            : [],
      ),
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_musicData.isEmpty || _styles.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }

    if (_selectedStyle == null) {
      return _buildStyleList();
    } else if (_selectedGenre == null) {
      return _buildGenreList();
    } else {
      return _buildSongList();
    }
  }

  Widget _buildStyleList() {
    final stylesList = _styles.keys.toList();
    return ListView.builder(
      key: ValueKey("styles"),
      itemCount: stylesList.length,
      itemBuilder: (context, index) {
        final style = stylesList[index];
        return _buildListTile(
          title: style,
          onTap: () {
            setState(() {
              _selectedStyle = style;
            });
          },
        );
      },
    );
  }

  Widget _buildGenreList() {
    final genres = _styles[_selectedStyle]!;
    return ListView.builder(
      key: ValueKey("genres"),
      itemCount: genres.length,
      itemBuilder: (context, index) {
        final genre = genres[index];
        return _buildListTile(
          title: _getFolderDisplayName(genre),
          onTap: () {
            setState(() {
              _selectedGenre = genre;
              _selectGenre(genre);
            });
          },
        );
      },
    );
  }

  Widget _buildSongList() {
    // Combine custom songs (both web and mobile) and standard genre songs
    final allSongs = [
      ..._webCustomSongs.keys, // Add web custom song names (keys of _webCustomSongs)
      ..._customSongs, // Add custom song paths for mobile
      ..._currentGenreSongs, // Add standard genre songs
    ];

    return ListView.builder(
      key: ValueKey("songs"),
      itemCount: allSongs.length,
      itemBuilder: (context, index) {
        final songUrl = allSongs[index];
        final isCustomWebSong = _webCustomSongs.containsKey(songUrl);
        final isCustomMobileSong = _customSongs.contains(songUrl);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Card(
            child: ListTile(
              title: Text(
                _cleanSongName(songUrl),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              trailing: isCustomWebSong || isCustomMobileSong
                  ? IconButton(
                icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                onPressed: () => _removeCustomSong(songUrl),
              )
                  : null,
              onTap: () => _playSong(songUrl),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListTile({required String title, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFolderDisplayName(String genre) {
    return folderDisplayNames[genre.toLowerCase()] ?? genre;
  }
}

const Map<String, String> genreToStyleMapping = {
  "waltz": "International Standard",
  "tango": "International Standard",
  "viennese waltz, vwaltz, v waltz, viennese": "International Standard",
  "foxtrot": "International Standard",
  "quickstep": "International Standard",
  "cha cha, chacha, cha-cha, cha": "International Latin",
  "rumba": "International Latin",
  "paso doble, paso": "International Latin",
  "samba": "International Latin",
  "jive": "International Latin",
  "east coast swing, ecs, east coast, country swing, club swing": "Country Western",
  "nightclub, night club": "Country Western",
  "polka": "Country Western",
  "triple two, tripletwo, triple two step": "Country Western",
  "two step, 2 step, 2step, 2st, twostep": "Country Western",
  "bachata": "Social Dances",
  "cumbia": "Social Dances",
  "hustle": "Social Dances",
  "jitterbug": "Social Dances",
  "merengue": "Social Dances",
  "salsa": "Social Dances",
  "west coast swing, wcs, west coast": "Social Dances",
  "zouk": "Social Dances",
};

const Map<String, String> folderDisplayNames = {
  "waltz": "Waltz (84-90 BPM)",
  "tango": "Tango (120-132 BPM)",
  "viennese waltz, vwaltz, v waltz, viennese": "Viennese Waltz (150-180 BPM)",
  "foxtrot": "Foxtrot (112-120 BPM)",
  "quickstep": "Quickstep (192-208 BPM)",
  "cha cha, chacha, cha-cha, cha": "Cha Cha (112-128 BPM)",
  "rumba": "Rumba (96-112 BPM)",
  "paso doble, paso": "Paso Doble (112-124 BPM)",
  "samba": "Samba (96-104 BPM)",
  "jive": "Jive (152-176 BPM)",
  "east coast swing, ecs, east coast, country swing, club swing": "East Coast Swing (126-144 BPM)",
  "nightclub, night club": "Nightclub (54-60 BPM)",
  "polka": "Polka (106-120 BPM)",
  "triple two, tripletwo, triple two step": "Triple Two (76-84 BPM)",
  "two step, 2 step, 2step, 2st, twostep": "Two Step (168-192 BPM)",
  "bachata": "Bachata",
  "cumbia": "Cumbia",
  "hustle": "Hustle",
  "jitterbug": "Jitterbug",
  "merengue": "Merengue",
  "salsa": "Salsa",
  "west coast swing, wcs, west coast": "West Coast Swing",
  "zouk": "Zouk",
};