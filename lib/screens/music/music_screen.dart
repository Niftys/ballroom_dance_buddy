import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
class MusicScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final ValueChanged<List<String>> onSongsReady;
  final GlobalKey<MusicScreenState> key;  // Explicit key type
  final ValueChanged<String> onSongTitleChanged;

  const MusicScreen({
    required this.audioPlayer,
    required this.onSongsReady,
    required this.key,
    required this.onSongTitleChanged,
  }) : super(key: key);

  @override
  MusicScreenState createState() => MusicScreenState();
}

class MusicScreenState extends State<MusicScreen> {
  Map<String, dynamic> _musicData = {};
  Map<String, List<String>> _styles = {};
  String? _selectedStyle;
  String? _selectedGenre;
  List<String> _currentGenreSongs = [];
  List<String> _customSongs = [];
  Map<String, Uint8List> _webCustomSongs = {};
  bool _isLoading = false;
  int currentSongIndex = -1;
  List<String> allSongs = [];

  @override
  void initState() {
    super.initState();
    _loadMusicData();
  }

  Future<void> _loadMusicData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final jsonString = await rootBundle.loadString('assets/music-files.json');
      final parsedData = json.decode(jsonString);
      final Map<String, List<String>> styles = {};

      parsedData.forEach((genre, songs) {
        final style = genreToStyleMapping[genre.toLowerCase()] ?? "Other";
        styles.putIfAbsent(style, () => []).add(genre);
      });

      setState(() {
        _musicData = parsedData;
        _styles = styles;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load music data: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
    if (kIsWeb) return;

    try {
      final directory = await _getGenreSpecificCustomSongsDirectory(genre);
      final files = directory.listSync().where((file) => file.path.endsWith('.mp3'));
      setState(() {
        _customSongs = files.map((file) => file.path).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load custom songs: $e")),
      );
    }
  }

  Future<void> _addCustomSongToGenre(String genre) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) return;

    try {
      if (kIsWeb) {
        final fileBytes = result.files.first.bytes;
        final fileName = result.files.first.name;
        if (fileBytes != null) {
          setState(() {
            _webCustomSongs[fileName] = fileBytes;
          });
        }
      } else {
        final file = File(result.files.first.path!);
        final directory = await _getGenreSpecificCustomSongsDirectory(genre);
        final newFile = await file.copy('${directory.path}/${file.uri.pathSegments.last}');
        setState(() {
          _customSongs.add(newFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add custom song: $e")),
      );
    }
  }

  Future<void> _removeCustomSong(String songPath) async {
    try {
      if (kIsWeb) {
        setState(() {
          _webCustomSongs.remove(songPath);
        });
      } else {
        final file = File(songPath);
        if (await file.exists()) {
          await file.delete();
        }
        setState(() {
          _customSongs.remove(songPath);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to remove song: $e")),
      );
    }
  }

  void _playSong(String songUrl) async {
    try {
      await widget.audioPlayer.stop();

      allSongs = [
        ..._webCustomSongs.keys,
        ..._customSongs,
        ..._currentGenreSongs,
      ];

      setState(() {
        currentSongIndex = allSongs.indexOf(songUrl);
      });

      if (currentSongIndex == -1) {
        throw Exception('Song not found in playlist');
      }

      final songTitle = _cleanSongName(songUrl);
      widget.onSongTitleChanged(songTitle);

      final newSource = kIsWeb && _webCustomSongs.containsKey(songUrl)
          ? AudioSource.uri(
        Uri.dataFromBytes(
          _webCustomSongs[songUrl]!,
          mimeType: 'audio/mpeg',
        ),
        tag: songTitle,
      )
          : AudioSource.uri(
        Uri.parse(songUrl),
        tag: songTitle,
      );

      await widget.audioPlayer.setAudioSource(newSource);
      await widget.audioPlayer.play();

      if (kDebugMode) {
        print('Now playing: $songTitle');
        print('Playlist index: $currentSongIndex/${allSongs.length}');
      }
    } catch (e) {
      print('Playback error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error playing song: ${e.toString()}")),
      );
    }
  }

  bool _isPlayingNextSong = false;

  void playNextSong() async {
    if (_isPlayingNextSong) {
      return;
    }

    _isPlayingNextSong = true;

    if (allSongs.isEmpty) return;
    try {
      if (currentSongIndex >= allSongs.length - 1) {
        _isPlayingNextSong = false;
        return;
      }

      await widget.audioPlayer.stop();
      currentSongIndex += 1;

      final nextSongUrl = allSongs[currentSongIndex];
      final songTitle = _cleanSongName(nextSongUrl);

      widget.onSongTitleChanged(songTitle);

      final newSource = AudioSource.uri(
        Uri.parse(nextSongUrl),
        tag: songTitle,
      );

      await widget.audioPlayer.setAudioSource(newSource);
      await widget.audioPlayer.play();
    } catch (e) {
      widget.onSongTitleChanged("Playback Error");
    }
    _isPlayingNextSong = false;
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
          style: Theme
              .of(context)
              .textTheme
              .titleLarge,
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Theme
          .of(context)
          .primaryColor))
          : _buildContent(),
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
    return Column(
      children: [
        _buildStyleRow(
          "International Standard",
          Theme.of(context).colorScheme.surface,
          SvgPicture.asset(
            'assets/icons/txblogo.svg',
            color: Theme.of(context).colorScheme.secondary,
            width: 40,
            height: 40,
          ),
        ),
        _buildStyleRow(
          "International Latin",
          Theme.of(context).colorScheme.surface,
          SvgPicture.asset(
            'assets/icons/latin.svg',
            color: Theme.of(context).colorScheme.secondary,
            width: 40,
            height: 40,
          ),
        ),
        _buildStyleRow(
          "Country Western",
          Theme.of(context).colorScheme.surface,
          SvgPicture.asset(
            'assets/icons/country.svg',
            color: Theme.of(context).colorScheme.secondary,
            width: 40,
            height: 40,
          ),
        ),
        _buildStyleRow(
          "Social Dances",
          Theme.of(context).colorScheme.surface,
          SvgPicture.asset(
            'assets/icons/social.svg',
            color: Theme.of(context).colorScheme.secondary,
            width: 40,
            height: 40,
          ),
        ),
      ],
    );
  }

  Widget _buildStyleRow(String style, Color color, Widget icon) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStyle = style;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0), // Slight margin for spacing
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding for text alignment
          decoration: BoxDecoration(
            color: color.withAlpha(50),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              icon, // Left-aligned icon
              const SizedBox(width: 16), // Space between icon and text
              Expanded(
                child: Text(
                  style,
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenreList() {
    final genres = _styles[_selectedStyle]!;

    return Column(
      children: genres.map((genre) {
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedGenre = genre;
                _selectGenre(genre);
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withAlpha(50),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _getFolderDisplayName(genre).replaceAll(RegExp(r"\s*\(.*?\)"), ""), // Remove BPM from genre name
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSongList() {
    final allSongs = [..._webCustomSongs.keys, ..._customSongs, ..._currentGenreSongs];

    return ListView.separated(
      key: ValueKey("songs"),
      itemCount: allSongs.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: Theme.of(context).colorScheme.surface),
      itemBuilder: (context, index) {
        final songUrl = allSongs[index];
        final isCustomSong = _webCustomSongs.containsKey(songUrl) || _customSongs.contains(songUrl);
        final cleanedName = _cleanSongName(songUrl);
        final hyphenIndex = cleanedName.indexOf(' - ');

        return InkWell(
          onTap: () => _playSong(songUrl),
          splashColor: Theme.of(context).primaryColor.withAlpha(25),
          highlightColor: Theme.of(context).primaryColor.withAlpha(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.music_note,
                    size: 20,
                    color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hyphenIndex != -1
                            ? cleanedName.substring(hyphenIndex + 3)
                            : cleanedName,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hyphenIndex != -1)
                        Text(
                          cleanedName.substring(0, hyphenIndex),
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (isCustomSong)
                  IconButton(
                    icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                    onPressed: () => _removeCustomSong(songUrl),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
              ],
            ),
          ),
        );
      },
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