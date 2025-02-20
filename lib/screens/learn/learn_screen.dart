import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../themes/colors.dart';
import '/services/database_service.dart';
import 'move_screen.dart';

class LearnScreen extends StatefulWidget {
  final void Function(bool) onFullscreenChange;

  const LearnScreen({required this.onFullscreenChange});

  @override
  _LearnScreenState createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allMoves = [];
  List<Map<String, dynamic>> _filteredMoves = [];
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
      if (mounted) {
        setState(() {
          _allMoves = moves;
          _filteredMoves = List.from(_allMoves);
        });
      }
    } catch (e) {
      if (kDebugMode) print("Error loading all moves: $e");
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (mounted) {
      setState(() {
        _isSearching = query.isNotEmpty;
        _filteredMoves = _allMoves.where((move) {
          final description = move['description'].toLowerCase();
          final style = move['style_name'].toLowerCase();
          final dance = move['dance_name'].toLowerCase();
          return description.contains(query) || style.contains(query) ||
              dance.contains(query);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentStyleId == null
              ? "Figure Finder"
              : _currentDanceId == null
              ? "Select Dance"
              : "Figures",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        leading: _currentStyleId != null
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (mounted) {
              setState(() {
                _currentDanceId != null
                    ? _currentDanceId = null
                    : _currentStyleId = null;
              });
            }
          },
        )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Search figures...",
                prefixIcon: Icon(Icons.search),
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupFiguresDynamically(List<Map<String, dynamic>> figures) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final figure in figures) {
      final level = figure['level'] as String;
      grouped.putIfAbsent(level, () => []);
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
        final level = move['level'] as String? ?? "Unknown";
        final levelColor = _levelColors[level] ?? Theme.of(context).colorScheme.surface;

        return GestureDetector(
          onTap: () => _navigateToMoveScreen(move),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: levelColor.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Move Name
                  Text(
                    move['description'],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  // Move Details (Style | Dance | Level)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      "${move['style_name']} | ${move['dance_name']} | $level",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    if (_isSearching) return _buildSearchResultList(_filteredMoves);

    if (_currentStyleId != null) {
      if (_currentDanceId != null) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseService.getFigures(
            styleId: _currentStyleId!,
            danceId: _currentDanceId!,
            level: '',
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
            } else if (snapshot.hasError) {
              return Center(child: const Text("Error loading figures."));
            } else {
              final filteredFigures = (snapshot.data ?? []).where((figure) {
                final description = figure['description'];
                return description != null &&
                    description.toLowerCase() != 'long wall' &&
                    description.toLowerCase() != 'short wall';
              }).toList();

              final styleName = _styles.firstWhere(
                    (style) => style['id'] == _currentStyleId,
                orElse: () => {'name': 'Unknown'},
              )['name'];

              final danceName = _dances.firstWhere(
                    (dance) => dance['id'] == _currentDanceId,
                orElse: () => {'name': 'Unknown'},
              )['name'];

              return _buildFigureList(filteredFigures, styleName, danceName);
            }
          },
        );
      }

      return FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseService.getDancesByStyleId(_currentStyleId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
          } else if (snapshot.hasError) {
            return Center(child: const Text("Error loading dances."));
          } else {
            return _buildDanceList(snapshot.data ?? []);
          }
        },
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService.getAllStyles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
        } else if (snapshot.hasError) {
          return Center(child: const Text("Error loading styles."));
        } else {
          return _buildStyleList(snapshot.data ?? []);
        }
      },
    );
  }

  Widget _buildStyleList(List<Map<String, dynamic>> styles) {
    _styles = styles;

    return Column(
      children: styles.map((style) {
        final styleName = style['name'];

        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (mounted) {
                setState(() {
                  _currentStyleId = style['id'];
                  _currentDanceId = null;
                });
              }
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
                  _getStyleIcon(styleName, context),
                  const SizedBox(width: 16), // Space between icon and text
                  Expanded(
                    child: Text(
                      styleName,
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

  Widget _buildDanceList(List<Map<String, dynamic>> dances) {
    _dances = dances;

    return Column(
      children: dances.map((dance) {
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (mounted) {
                setState(() {
                  _currentDanceId = dance['id'];
                });
              }
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
                      dance['name'],
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

  Widget _buildFigureList(List<Map<String, dynamic>> figures, String styleName, String danceName) {
    final groupedFigures = _groupFiguresDynamically(figures);

    // Sort levels in a specific order
    const desiredOrder = ['Bronze', 'Silver', 'Gold', 'Newcomer IV', 'Newcomer III', 'Newcomer II'];
    final sortedLevels = groupedFigures.keys.toList()
      ..sort((a, b) {
        final indexA = desiredOrder.indexOf(a);
        final indexB = desiredOrder.indexOf(b);
        return (indexA == -1 ? double.infinity : indexA.toDouble())
            .compareTo(indexB == -1 ? double.infinity : indexB.toDouble());
      });

    String? _selectedLevel;

    return StatefulBuilder(builder: (context, setState) {
      return Row(
        children: [
          // Left: Level Selection
          Expanded(
            flex: 1, // Takes up 40% of the screen
            child: Container(
              color: Theme.of(context).colorScheme.surface.withAlpha(50),
              child: ListView(
                children: sortedLevels.map((level) {
                  final levelColor = _levelColors[level] ?? Theme.of(context).colorScheme.onSurface;

                  return GestureDetector(
                    onTap: () {
                      if (mounted) {
                        setState(() => _selectedLevel = level);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: _selectedLevel == level
                            ? levelColor.withAlpha(75)
                            : Colors.transparent,
                        border: Border(
                          left: BorderSide(
                            color: _selectedLevel == level ? levelColor : Colors.transparent,
                            width: 4.0,
                          ),
                        ),
                      ),
                      child: Text(
                        level,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Container(
            width: 2,
            color: Colors.grey,
          ),
          // Right: Figure List
          Expanded(
            flex: 2, // Takes up 60% of the screen
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).colorScheme.surface,
              child: _selectedLevel == null
                  ? Center(
                child: Text(
                  "Select a level",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              )
                  : ListView(
                children: groupedFigures[_selectedLevel]!.map((figure) {
                  final move = {
                    'style': styleName,
                    'dance': danceName,
                    'level': _selectedLevel,
                    'description': figure['description'] ?? 'Unknown Description',
                    'video_url': figure['video_url'] ?? '',
                    'start': figure['start'] ?? 0,
                    'end': figure['end'] ?? 0,
                  };

                  return GestureDetector(
                    onTap: () => _navigateToMoveScreen(move),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withAlpha(50),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        figure['description'] ?? 'Unknown Description',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      );
    });
  }

  void _navigateToMoveScreen(Map<String, dynamic> move) {
    if (kDebugMode) print("Navigating to MoveScreen with move: $move");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoveScreen(move: move),
      ),
    );
  }

  Widget _getStyleIcon(String styleName, BuildContext context) {
    final Map<String, String> iconPaths = {
      "International Standard": 'assets/icons/txblogo.svg',
      "International Latin": 'assets/icons/latin.svg',
      "Country Western": 'assets/icons/country.svg',
      "Social Dances": 'assets/icons/social.svg',
      "American Smooth": 'assets/icons/smooth.svg',
      "American Rhythm": 'assets/icons/rhythm.svg',
    };

    if (!iconPaths.containsKey(styleName)) return Container();

    return SvgPicture.asset(
      iconPaths[styleName]!,
      width: 40,
      height: 40,
      color: Theme.of(context).colorScheme.secondary, // Access `context` here
    );
  }

  final Map<String, Color> _levelColors = {
    "Bronze": AppColors.bronze,
    "Silver": AppColors.silver,
    "Gold": AppColors.gold,
    "Newcomer IV": AppColors.primary,
    "Newcomer III": AppColors.primary,
    "Newcomer II": AppColors.primary,
  };
}