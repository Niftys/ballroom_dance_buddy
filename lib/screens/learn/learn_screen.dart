import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/services/database_service.dart';
import 'move_screen.dart';

class LearnScreen extends StatefulWidget {
  final void Function(bool) onFullscreenChange;

  LearnScreen({required this.onFullscreenChange});

  @override
  _LearnScreenState createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  List<Map<String, dynamic>> _allMoves = [];
  List<Map<String, dynamic>> _filteredMoves = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  int? _currentStyleId;
  int? _currentDanceId;

  List<Map<String, dynamic>> _styles = [];
  List<Map<String, dynamic>> _dances = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAllMoves();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllMoves() async {
    try {
      final moves = await DatabaseService.getAllFigures();
      setState(() {
        _allMoves.clear();  // Clear before inserting new data
        _allMoves.addAll(moves);
        _filteredMoves = List.from(_allMoves);
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error loading all moves: $e");
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredMoves = _allMoves.where((move) {
        final description = move['description'].toLowerCase();
        final style = move['style_name'].toLowerCase();
        final dance = move['dance_name'].toLowerCase();
        return description.contains(query) || style.contains(query) || dance.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 5,
        backgroundColor: Colors.white,
        shadowColor: Colors.black54,
        title: Text(
          _currentStyleId == null
              ? "Figure Finder"
              : _currentDanceId == null
              ? "Select Dance"
              : "Figures",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        leading: _currentStyleId != null
            ? IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            setState(() {
              if (_currentDanceId != null) {
                _currentDanceId = null;
              } else {
                _currentStyleId = null;
              }
            });
          },
        )
            : null,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_currentStyleId == null ? 60.0 : 0.0),
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: _currentStyleId == null
                ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                key: ValueKey("search_field"),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search figures...",
                  prefixIcon: Icon(Icons.search, color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
            )
                : SizedBox.shrink(),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: _buildContent(),
      ),
      backgroundColor: Colors.grey.shade100,
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupFiguresDynamically(List<Map<String, dynamic>> figures) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final figure in figures) {
      final level = figure['level'] as String;

      grouped.putIfAbsent(level, () => []);

      // Ensure no duplicates in the list for the level
      if (!grouped[level]!.any((item) => item['description'] == figure['description'])) {
        grouped[level]!.add(figure);
      }
    }

    return grouped;
  }

  Widget _buildSearchResultList(List<Map<String, dynamic>> moves) {
    return ListView.builder(
      itemCount: moves.length,
      itemBuilder: (context, index) {
        final move = moves[index];
        return _buildListTile(
          title: move['description'],
          subtitle: "${move['style_name']} | ${move['dance_name']} | ${move['level']}",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MoveScreen(move: move),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContent() {
    if (_isSearching) {
      return _buildSearchResultList(_filteredMoves);
    }

    if (_currentStyleId != null) {
      if (_currentDanceId != null) {
        // Fetch figures for the selected style and dance
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseService.getFigures(
            styleId: _currentStyleId!,
            danceId: _currentDanceId!,
            level: '',
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: Colors.purple));
            } else if (snapshot.hasError) {
              return Center(child: Text("Error loading figures."));
            } else {
              final filteredFigures = (snapshot.data ?? []).where((figure) {
                final description = figure['description'];
                return description != null &&
                    description.toLowerCase() != 'long wall' &&
                    description.toLowerCase() != 'short wall';
              }).toList();

              // Pass style and dance names into _buildFigureList
              final styleName = _styles.firstWhere(
                      (style) => style['id'] == _currentStyleId,
                  orElse: () => {'name': 'Unknown'})['name'];

              final danceName = _dances.firstWhere(
                      (dance) => dance['id'] == _currentDanceId,
                  orElse: () => {'name': 'Unknown'})['name'];

              return _buildFigureList(filteredFigures, styleName, danceName);
            }
          },
        );
      }

      // Fetch dances for the selected style
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseService.getDancesByStyleId(_currentStyleId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.purple));
          } else if (snapshot.hasError) {
            return Center(child: Text("Error loading dances."));
          } else {
            return _buildDanceList(snapshot.data ?? []);
          }
        },
      );
    }

    // Fetch and display styles
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService.getAllStyles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.purple));
        } else if (snapshot.hasError) {
          return Center(child: Text("Error loading styles."));
        } else {
          return _buildStyleList(snapshot.data ?? []);
        }
      },
    );
  }

  Widget _buildStyleList(List<Map<String, dynamic>> styles) {
    _styles = styles;

    return ListView.builder(
      itemCount: styles.length,
      itemBuilder: (context, index) {
        final style = styles[index];
        return _buildListTile(
          title: style['name'],
          onTap: () {
            setState(() {
              _currentStyleId = style['id'];
              _currentDanceId = null;
            });
          },
        );
      },
    );
  }

  Widget _buildDanceList(List<Map<String, dynamic>> dances) {
    _dances = dances;

    return ListView.builder(
      itemCount: dances.length,
      itemBuilder: (context, index) {
        final dance = dances[index];
        return _buildListTile(
          title: dance['name'],
          onTap: () {
            setState(() {
              _currentDanceId = dance['id'];
            });
          },
        );
      },
    );
  }

  Widget _buildFigureList(List<Map<String, dynamic>> figures, String styleName, String danceName) {
    final groupedFigures = _groupFiguresDynamically(figures);

    return ListView(
      children: groupedFigures.entries.map((entry) {
        final level = entry.key;
        final moves = entry.value;

        return ExpansionTile(
          title: Text(
            level,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: level == 'Bronze'
                  ? Colors.brown
                  : level == 'Silver'
                  ? Colors.grey
                  : level == 'Gold'
                  ? Colors.amber
                  : Colors.deepPurple,
            ),
          ),
          children: moves.map((figure) {
            final move = {
              'style': styleName,
              'dance': danceName,
              'level': level,
              'description': figure['description'] ?? 'Unknown Description',
              'video_url': figure['video_url'] ?? '',
              'start': figure['start'] ?? 0,
              'end': figure['end'] ?? 0,
            };

            return Align(
              alignment: Alignment.centerLeft,
              child: _buildListTile(
                title: figure['description'] ?? 'Unknown Description',
                onTap: () {
                  if (kDebugMode) {
                    print("Navigating to MoveScreen with move: $move");
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MoveScreen(move: move),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildListTile({required String title, String? subtitle, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Card(
        elevation: 3,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          highlightColor: Colors.purple.withOpacity(0.2),
          splashColor: Colors.purple.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
