import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../themes/colors.dart';

List<String> _getApplicableLevels(String level) {
  const standardLevels = ['Bronze', 'Silver', 'Gold'];
  const countryWesternLevels = ['Newcomer IV', 'Newcomer III', 'Newcomer II'];

  if (standardLevels.contains(level)) {
    return standardLevels.sublist(0, standardLevels.indexOf(level) + 1);
  } else if (countryWesternLevels.contains(level)) {
    return countryWesternLevels.sublist(0, countryWesternLevels.indexOf(level) + 1);
  }
  return [level];
}

class AddFigureScreenFirestore extends StatefulWidget {
  final String choreoDocId;
  final String styleName;
  final String danceName;

  final String level;

  const AddFigureScreenFirestore({
    Key? key,
    required this.choreoDocId,
    required this.styleName,
    required this.danceName,
    required this.level,
  }) : super(key: key);

  @override
  _AddFigureScreenFirestoreState createState() => _AddFigureScreenFirestoreState();
}

class _AddFigureScreenFirestoreState extends State<AddFigureScreenFirestore> {
  Map<String, List<Map<String, dynamic>>> _organizedFigures = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedLevel;
  String? _currentStyleName;
  String? _currentDanceName;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allMoves = [];
  List<Map<String, dynamic>> _filteredMoves = [];
  bool _isSearching = false;
  Set<String> _loadingFigures = {};
  bool _isAddingCustomFigure = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    _currentStyleName = widget.styleName;
    _currentDanceName = widget.danceName;

    _loadAvailableFigures();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchQuery = '';
          _isSearching = false;
          _filteredMoves = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _searchQuery = query;
        _isSearching = true;
        _filteredMoves = _allMoves.where((figure) {
          final description = figure['description'].toString().toLowerCase();
          return description.contains(query);
        }).toList();
      });
    }
  }

  Future<void> _loadAvailableFigures() async {
    if (_currentStyleName == null || _currentDanceName == null) return;

    setState(() => _isLoading = true);

    try {
      final standardFigures = await FirestoreService.getFiguresByStyleAndDance(
        _currentStyleName!,
        _currentDanceName!,
      );

      final userCustomFigures = await FirestoreService.getUserCustomFigures(
        styleName: _currentStyleName!,
        danceName: _currentDanceName!,
      );

      final applicableLevels = _getApplicableLevels(widget.level);

      final combinedFigures = [...standardFigures, ...userCustomFigures]
          .where((figure) {
        final figureLevel = figure['level'] ?? 'Custom';
        return applicableLevels.contains(figureLevel) || figureLevel == 'Custom';
      })
          .toList();

      if (mounted) {
        setState(() {
          _allMoves = combinedFigures;
          _organizedFigures = _groupFiguresByLevel(combinedFigures);
          _isLoading = false;
          _selectedLevel = _organizedFigures.keys.firstWhere(
                (k) => k == widget.level,
            orElse: () => _organizedFigures.keys.first,
          );
        });
      }
    } catch (e) {
      debugPrint("Error loading figures: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupFiguresByLevel(List<Map<String, dynamic>> figures) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final figure in figures) {
      final level = figure['level'] ?? 'Custom';
      grouped.putIfAbsent(level, () => []).add(figure);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final indexA = _desiredLevelOrder.indexOf(a);
        final indexB = _desiredLevelOrder.indexOf(b);
        return (indexA == -1 ? 999 : indexA).compareTo(indexB == -1 ? 999 : indexB);
      });

    return Map.fromEntries(sortedKeys.map((key) => MapEntry(key, grouped[key]!)));
  }

  void _addFigureToFirestore(Map<String, dynamic> figure, BuildContext context) async {
    if (!mounted) return;

    final loadingId = figure['id'] ?? '${figure['description']}_${DateTime.now().millisecondsSinceEpoch}';

    if (_loadingFigures.contains(loadingId)) {
      return;
    }

    setState(() {
      _loadingFigures.add(loadingId);
    });

    try {
      final nextPosition = await _getNextPosition();

      final figureData = {
        'description': figure['description'],
        'level': figure['level'],
        'video_url': figure['video_url'] ?? '',
        'start': figure['start'] ?? 0,
        'end': figure['end'] ?? 0,
        'position': nextPosition,
        'notes': '',
      };

      await FirestoreService.addFigureToChoreography(
        userId: FirebaseAuth.instance.currentUser!.uid,
        choreoId: widget.choreoDocId,
        figureData: figureData,
      );

      if (!mounted) return;

      setState(() {
        _loadingFigures.remove(loadingId);
      });

      Navigator.pop(context);
    } catch (e) {
      debugPrint("Error adding figure: $e");
      if (!mounted) return;

      setState(() {
        _loadingFigures.remove(loadingId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add figure")),
      );
    }
  }

  Future<int> _getNextPosition() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('choreographies')
        .doc(widget.choreoDocId)
        .collection('figures')
        .orderBy('position', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      final currentMax = snap.docs.first.data()['position'] ?? 0;
      return currentMax + 1;
    }
    return 0;
  }

  void _showDeleteConfirmation(Map<String, dynamic> figure, BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Custom Figure?"),
        content: Text("This will permanently remove it from your collection."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: Theme.of(context).textTheme.titleSmall),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteLocalCustomFigure(figure, context);
            },
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addCustomFigure(BuildContext context) async {
    if (_isAddingCustomFigure) return;

    setState(() {
      _isAddingCustomFigure = true;
    });

    final TextEditingController descriptionController = TextEditingController();

    if (!mounted) return;

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text("Add Custom Figure"),
            content: TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: "Figure Description"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text("Cancel", style: Theme.of(context).textTheme.titleSmall),
              ),
              ElevatedButton(
                onPressed: () async {
                  final description = descriptionController.text.trim();
                  if (description.isNotEmpty) {
                    showDialog(
                      context: dialogContext,
                      barrierDismissible: false,
                      builder: (context) => Center(child: CircularProgressIndicator()),
                    );

                    await FirestoreService.addCustomFigure(
                      description: description,
                      styleName: widget.styleName,
                      danceName: widget.danceName,
                    );

                    if (!dialogContext.mounted) return;

                    Navigator.pop(dialogContext);
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      );

      descriptionController.dispose();

      if (result == true) {
        await _loadAvailableFigures();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Custom figure saved!")),
        );
      }
    } catch (e) {
      debugPrint("Error adding custom figure: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add custom figure")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingCustomFigure = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Figure"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search figures...",
                prefixIcon: Icon(Icons.search),
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: _isSearching
                ? _buildSearchResults()
                : _buildDefaultFigureList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isAddingCustomFigure ? null : () => _addCustomFigure(context),
        child: _isAddingCustomFigure
            ? CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }

  Widget _buildSearchResults() {
    if (_filteredMoves.isEmpty) {
      return Center(
        child: Text("No figures found matching your search."),
      );
    }

    return ListView.builder(
      itemCount: _filteredMoves.length,
      itemBuilder: (context, index) {
        final move = _filteredMoves[index];
        final level = move['level'] as String? ?? "Unknown";
        final levelColor = _getLevelColor(level);

        final loadingId = move['id'] ?? '${move['description']}_${index}';
        final isLoading = _loadingFigures.contains(loadingId);

        return GestureDetector(
          onTap: isLoading ? null : () => _addFigureToFirestore(move, context),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: levelColor.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: levelColor.withAlpha(75), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          move['description'] ?? 'Unnamed',
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLoading)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: levelColor,
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

  Widget _buildDefaultFigureList() {
    return StatefulBuilder(builder: (context, setState) {
      const desiredOrder = [
        'Bronze', 'Silver', 'Gold',
        'Newcomer IV', 'Newcomer III', 'Newcomer II',
        'Custom'
      ];

      final sortedLevels = _organizedFigures.keys.toList()
        ..sort((a, b) {
          final indexA = desiredOrder.indexOf(a);
          final indexB = desiredOrder.indexOf(b);
          return (indexA == -1 ? 999999 : indexA)
              .compareTo(indexB == -1 ? 999999 : indexB);
        });

      if (_selectedLevel == null && sortedLevels.isNotEmpty) {
        _selectedLevel = sortedLevels.first;
      }

      return Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              color: Theme.of(context).colorScheme.surface.withAlpha(50),
              child: ListView(
                children: sortedLevels.map((level) {
                  final levelColor = _getLevelColor(level);
                  final isSelected = (_selectedLevel == level);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedLevel = level),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: isSelected ? levelColor.withAlpha(75) : Colors.transparent,
                        border: Border(
                          left: BorderSide(
                            color: isSelected ? levelColor : Colors.transparent,
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
          Container(width: 2, color: Colors.grey),

          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).colorScheme.surface,
              child: _selectedLevel == null
                  ? Center(child: Text("Select a level"))
                  : ListView(
                children: (_organizedFigures[_selectedLevel] ?? []).map((figure) {

                  final loadingId = figure['id'] ?? '${figure['description']}_${DateTime.now().millisecondsSinceEpoch}';
                  final isLoading = _loadingFigures.contains(loadingId);

                  return GestureDetector(
                    onTap: isLoading ? null : () => _addFigureToFirestore(figure, context),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      margin: const EdgeInsets.only(bottom: 12.0),
                      decoration: BoxDecoration(
                        color: _getLevelColor(_selectedLevel!).withAlpha(25),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: _getLevelColor(_selectedLevel!).withAlpha(50),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              figure['description'] ?? 'Unnamed',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (isLoading)
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _getLevelColor(_selectedLevel!),
                              ),
                            )
                          else if (figure['level'] == 'Custom')
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red.shade300),
                              onPressed: () => _showDeleteConfirmation(figure, context),
                            ),
                        ],
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

  void _deleteLocalCustomFigure(Map<String, dynamic> figure, BuildContext context) async {
    if (!mounted) return;

    final loadingId = figure['id'] ?? '${figure['description']}_delete';

    setState(() {
      _loadingFigures.add(loadingId);
    });

    try {
      await FirestoreService.deleteCustomFigure(figureId: figure['id']);

      await FirestoreService.deleteFigureFromChoreography(
        userId: FirebaseAuth.instance.currentUser!.uid,
        choreoId: widget.choreoDocId,
        figureId: figure['id'],
      );

      await _loadAvailableFigures();
    } catch (e) {
      debugPrint("Error deleting figure: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete figure.")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingFigures.remove(loadingId);
        });
      }
    }
  }
}

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

const _desiredLevelOrder = [
  'Bronze', 'Silver', 'Gold',
  'Newcomer IV', 'Newcomer III', 'Newcomer II',
  'Custom'
];