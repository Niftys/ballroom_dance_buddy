import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../services/firestore_service.dart';
import '../../themes/colors.dart';
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
  String? _currentStyleName;
  String? _currentDanceName;
  List<Map<String, dynamic>> _styles = [];
  List<Map<String, dynamic>> _dances = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAllMovesForSearch();
    _loadStyles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStyles() async {
    try {
      final styles = await FirestoreService.getAllStyles();

      styles.sort((a, b) {
        final indexA = desiredStyleOrder.indexOf(a['name']);
        final indexB = desiredStyleOrder.indexOf(b['name']);
        return (indexA == -1 ? double.infinity : indexA.toDouble())
            .compareTo(indexB == -1 ? double.infinity : indexB.toDouble());
      });

      if (mounted) {
        setState(() {
          _styles = styles;
          _currentStyleName = null;
          _currentDanceName = null;
          _dances = [];
          _allMoves = [];
          _filteredMoves = [];
        });
      }
    } catch (e) {
      print("❌ Error loading styles: $e");
    }
  }


  Future<void> _loadDances() async {
    if (_currentStyleName == null) return;

    try {
      final dances = await FirestoreService.getDancesByStyleName(_currentStyleName!);

      dances.sort((a, b) {
        final indexA = desiredDanceOrder.indexOf(a['name']);
        final indexB = desiredDanceOrder.indexOf(b['name']);
        return (indexA == -1 ? double.infinity : indexA.toDouble())
            .compareTo(indexB == -1 ? double.infinity : indexB.toDouble());
      });

      if (mounted) {
        setState(() {
          _dances = dances;
          _currentDanceName = null;
          _filteredMoves = [];
        });
      }
    } catch (e) {
      print("❌ Error loading dances: $e");
    }
  }

  Future<void> _loadDanceFigures() async {
    if (_currentStyleName == null || _currentDanceName == null) return;

    try {
      print("🔍 Fetching figures for $_currentStyleName - $_currentDanceName");

      final figures = await FirestoreService.getFiguresByStyleAndDance(
        _currentStyleName!,
        _currentDanceName!,
      );

      if (mounted) {
        setState(() {
          _filteredMoves = figures.where((figure) {
            final description = (figure['description'] as String?)?.toLowerCase() ?? '';
            final level = (figure['level'] as String?) ?? '';

            return level != 'Custom' &&
                !description.contains('long wall') &&
                !description.contains('short wall');
          }).toList();
        });
      }
    } catch (e) {
      print("❌ Error loading figures: $e");
    }
  }

  Future<void> _loadAllMovesForSearch() async {
    try {
      print("🔍 Fetching ALL figures for search...");
      final allFigures = await FirestoreService.getAllFigures();

      if (mounted) {
        setState(() {
          _allMoves = allFigures.where((figure) {
            final description = (figure['description'] as String?)?.toLowerCase() ?? '';
            final level = (figure['level'] as String?) ?? '';

            return level != 'Custom' &&
                !description.contains('long wall') &&
                !description.contains('short wall');
          }).toList();
        });
      }
    } catch (e) {
      print("❌ Error loading moves: $e");
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _filteredMoves = _currentDanceName != null
            ? _allMoves.where((move) =>
        move['style'] == _currentStyleName &&
            move['dance'] == _currentDanceName).toList()
            : List.from(_allMoves);
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _filteredMoves = _allMoves.where((move) {
        final description = move['description'].toString().toLowerCase();
        final matchesQuery = description.contains(query);

        if (_currentDanceName != null) {
          return matchesQuery &&
              move['style'] == _currentStyleName &&
              move['dance'] == _currentDanceName;
        }

        return matchesQuery;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentStyleName == null
              ? "Figure Finder"
              : _currentDanceName == null
              ? "Select Dance"
              : "Figures",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        leading: _currentStyleName != null
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (mounted) {
              setState(() {
                if (_currentDanceName != null) {
                  _currentDanceName = null;
                } else {
                  _currentStyleName = null;
                }
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
    return Column(
      children: [
        Expanded(
          child: moves.isEmpty
              ? Center(
            child: Text(
              "No figures found matching your search.",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          )
              : ListView.builder(
            itemCount: moves.length,
            itemBuilder: (context, index) {
              final move = moves[index];
              final level = move['level'] as String? ?? "Unknown";
              final levelColor = _getLevelColor(level);

              return GestureDetector(
                onTap: () => _navigateToMoveScreen(move),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: levelColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: levelColor.withAlpha(75), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          move['description'],
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: levelColor.withAlpha(50),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  level,
                                  style: TextStyle(
                                    color: levelColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${move['style']} | ${move['dance']}",
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withOpacity(0.7),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isSearching) {
      return _buildSearchResultList(_filteredMoves);
    }

    if (_currentStyleName == null) {
      return _buildStyleList(_styles);
    }

    if (_currentDanceName == null) {
      return _buildDanceList(_dances);
    }

    return _buildFigureList(_filteredMoves, _currentStyleName!, _currentDanceName!);
  }

  Widget _buildStyleList(List<Map<String, dynamic>> styles) {
      return Column(
        children: styles.map((style) {
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentStyleName = style['name'];
                  _currentDanceName = null;
                  _loadDances();
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _getStyleIcon(style['name'], context),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        style['name'],
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
      return Column(
        children: dances.map((dance) {
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (mounted) {
                  setState(() {
                    _currentDanceName = dance['name'];
                    _loadDanceFigures();
                  });
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dance['name'],
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
  }


  Widget _buildFigureList(List<Map<String, dynamic>> figures, String styleName, String danceName) {
    final groupedFigures = _groupFiguresDynamically(figures);

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
          Expanded(
            flex: 1,
            child: Container(
              color: Theme.of(context).colorScheme.surface.withAlpha(50),
              child: ListView(
                children: sortedLevels.map((level) {
                  final levelColor = _getLevelColor(level);

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
          Expanded(
            flex: 2,
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
                  final levelColor = _getLevelColor(_selectedLevel!);
                  final move = {
                    'style': _currentStyleName,
                    'dance': _currentDanceName,
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
                      margin: const EdgeInsets.only(bottom: 12.0),
                      decoration: BoxDecoration(
                        color: levelColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: levelColor.withAlpha(50), width: 1),
                      ),
                      child: Text(
                        figure['description'] ?? 'Unknown Description',
                        style: Theme.of(context).textTheme.titleMedium,
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
      color: Theme.of(context).colorScheme.secondary,
    );
  }
}

const desiredDanceOrder = [
  "Waltz",
  "Tango",
  "Foxtrot",
  "Quickstep",
  "Viennese Waltz",
  "Cha Cha",
  "Rumba",
  "Swing",
  "Mambo",
  "Bolero",
  "Samba",
  "Paso Doble",
  "Jive",
  "Triple Two",
  "Nightclub",
  "Country Waltz",
  "Polka",
  "Country Cha Cha",
  "East Coast Swing",
  "Two Step",
  "West Coast Swing",
];

const desiredStyleOrder = [
  "International Standard",
  "International Latin",
  "American Smooth",
  "American Rhythm",
  "Country Western",
  "Social Dances"
];

const desiredOrder = [
  'Bronze',
  'Silver',
  'Gold',
  'Newcomer IV',
  'Newcomer III',
  'Newcomer II'
];

Color _getLevelColor(String level) {
  switch (level) {
    case 'Bronze':
      return AppColors.bronze;
    case 'Silver':
      return AppColors.silver;
    case 'Gold':
      return AppColors.gold;
    case 'Newcomer IV':
    case 'Newcomer III':
    case 'Newcomer II':
      return AppColors.primary;
    case 'Custom':
      return AppColors.highlight;
    default:
      return AppColors.highlight;
  }
}