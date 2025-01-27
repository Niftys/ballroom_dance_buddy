import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;

class DatabaseService {
  static Future<Database> initializeDB() async {
    // Use appropriate factory based on platform
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String path = kIsWeb
        ? 'choreography.db' // No full path for web
        : join(await getDatabasesPath(), 'choreography.db');

    return openDatabase(
      path,
      version: 57,
      onCreate: (database, version) async {
        if (kDebugMode) print("Creating database...");
        await _createTables(database);
        await _insertInitialData(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (kDebugMode) print("Upgrading database...");
        await _dropTables(database);
        await _createTables(database);
        await _insertInitialData(database);
      },
    );
  }

  static Future<void> _createTables(Database database) async {
    await database.execute('''
      CREATE TABLE styles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      );
    ''');
    await database.execute('''
      CREATE TABLE dances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        style_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY(style_id) REFERENCES styles(id)
      );
    ''');
    await database.execute('''
      CREATE TABLE figures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        style_id INTEGER NOT NULL,
        dance_id INTEGER NOT NULL,
        level TEXT NOT NULL,
        description TEXT NOT NULL COLLATE NOCASE,
        notes TEXT DEFAULT '' COLLATE NOCASE,
        video_url TEXT,
        start INTEGER DEFAULT 0,
        end INTEGER DEFAULT 0,
        custom BOOLEAN DEFAULT 0,
        UNIQUE(style_id, dance_id, description),
        FOREIGN KEY(style_id) REFERENCES styles(id),
        FOREIGN KEY(dance_id) REFERENCES dances(id)
      );
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS choreographies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        style_id INTEGER NOT NULL,
        dance_id INTEGER NOT NULL,
        level TEXT NOT NULL,
        FOREIGN KEY(style_id) REFERENCES styles(id),
        FOREIGN KEY(dance_id) REFERENCES dances(id)
      );
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS choreography_figures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        choreography_id INTEGER NOT NULL,
        figure_id INTEGER NOT NULL,
        position INTEGER NOT NULL,
        notes TEXT DEFAULT '',
        FOREIGN KEY(choreography_id) REFERENCES choreographies(id),
        FOREIGN KEY(figure_id) REFERENCES figures(id)
      );
    ''');
  }

  static Future<void> _dropTables(Database database) async {
    await database.execute("DROP TABLE IF EXISTS styles");
    await database.execute("DROP TABLE IF EXISTS dances");
    await database.execute("DROP TABLE IF EXISTS figures");
  }

  static Future<void> _insertInitialData(Database database) async {
    if (kDebugMode) {
      print("Inserting data from JSON...");
    }
    await _insertFiguresFromJson(database);
    if (kDebugMode) {
      print("Data successfully inserted from JSON.");
    }
  }

  static Future<void> _insertFiguresFromJson(Database database) async {
    final String figuresJson = await rootBundle.loadString('assets/figures.json');
    final List<dynamic> stylesData = json.decode(figuresJson);

    for (var style in stylesData) {
      final styleId = await database.insert(
        'styles',
        {'name': style['style']},
        conflictAlgorithm: ConflictAlgorithm.ignore,  // Avoid duplicate styles
      );

      for (var dance in style['dances']) {
        final danceId = await database.insert(
          'dances',
          {
            'style_id': styleId,
            'name': dance['name'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,  // Avoid duplicate dances
        );

        final levels = dance['levels'];
        levels.forEach((level, figures) async {
          for (var figure in figures) {
            try {
              await database.insert(
                'figures',
                {
                  'style_id': styleId,
                  'dance_id': danceId,
                  'level': level,
                  'description': figure['description'],
                  'notes': figure['notes'] ?? '',
                  'video_url': figure['video_url'] ?? '',
                  'start': figure['start'] ?? 0,
                  'end': figure['end'] ?? 0,
                },
                conflictAlgorithm: ConflictAlgorithm.ignore,  // Skip duplicate figures
              );
            } catch (e) {
              if (kDebugMode) {
                print("Duplicate figure skipped: ${figure['description']}");
              }
            }
          }
        });
      }
    }
  }

static Future<void> addOrUpdateChoreography({
    required String name,
    required int styleId,
    required int danceId,
    required String level,
  }) async {
    final db = await initializeDB();

    await db.insert(
      'choreographies',
      {
        'name': name,
        'style_id': styleId,
        'dance_id': danceId,
        'level': level,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteMissingChoreographies(List<int> currentIds) async {
    final db = await initializeDB();

    final existingIds = (await db.query('choreographies')).map((e) => e['id'] as int).toList();
    for (var id in existingIds) {
      if (!currentIds.contains(id)) {
        await db.delete('choreographies', where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  static Future<Database> _db() => initializeDB();

  static Future<Map<String, dynamic>> exportFiguresToJson() async {
    final db = await _db();
    final styles = await db.query('styles');
    final result = [];

    for (var style in styles) {
      final styleId = style['id'];
      final styleName = style['name'];
      final dances = await db.query('dances', where: 'style_id = ?', whereArgs: [styleId]);

      final danceData = [];
      for (var dance in dances) {
        final danceId = dance['id'];
        final danceName = dance['name'];
        final figures = await db.query('figures', where: 'dance_id = ?', whereArgs: [danceId]);

        final levels = {};
        for (var figure in figures) {
          final level = figure['level'];
          if (!levels.containsKey(level)) {
            levels[level] = [];
          }
          levels[level].add({
            'description': figure['description'],
          });
        }
        danceData.add({
          'name': danceName,
          'levels': levels,
        });
      }
      result.add({
        'style': styleName,
        'dances': danceData,
      });
    }
    return {'styles': result};
  }

/// Fetch all choreographies with related styles and dances
  static Future<List<Map<String, dynamic>>> getChoreographies() async {
    final db = await _db();
    return await db.rawQuery('''
      SELECT choreographies.*, 
             styles.name AS style_name, 
             dances.name AS dance_name 
      FROM choreographies
      JOIN styles ON choreographies.style_id = styles.id
      JOIN dances ON choreographies.dance_id = dances.id
    ''');
  }

  static Future<int> addChoreography({
    required String name,
    int? styleId,
    int? danceId,
    String level = 'Bronze',
  }) async {
    final db = await _db();

    if (name.isEmpty) {
      throw Exception("Name is required to add a choreography.");
    }

    if (styleId == null || danceId == null) {
      throw Exception("Style and Dance IDs are required to add a choreography.");
    }

    return await db.insert('choreographies', {
      'name': name,
      'style_id': styleId,
      'dance_id': danceId,
      'level': level,
    });
  }

  /// Delete a choreography and its associated figures
  static Future<void> deleteChoreography(int choreographyId) async {
    final db = await _db();

    // Remove all figures associated with the choreography
    await db.delete(
      'choreography_figures',
      where: 'choreography_id = ?',
      whereArgs: [choreographyId],
    );

    // Remove the choreography itself
    await db.delete(
      'choreographies',
      where: 'id = ?',
      whereArgs: [choreographyId],
    );
  }

  static Future<void> updateChoreography({
    required int id,
    required String name,
    required int styleId,
    required int danceId,
    required String level,
  }) async {
    final db = await _db();
    await db.update(
      'choreographies',
      {
        'name': name,
        'style_id': styleId,
        'dance_id': danceId,
        'level': level,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> addCustomFigure({
    required int choreographyId,
    required int styleId,
    required int danceId,
    required String description,
    String notes = '',
  }) async {
    final db = await _db();

    // Insert the custom figure into the figures table for the specific style and dance
    final figureId = await db.insert('figures', {
      'style_id': styleId,
      'dance_id': danceId,
      'level': 'Custom',  // Mark it as a custom figure
      'description': description,
      'notes': notes,
      'custom': 1,
    });

    return figureId;
  }

  static Future<int> getStyleIdByName(String name) async {
    final db = await _db();
    final result = await db.query(
      'styles',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['id'] as int;
    } else {
      throw Exception("Style not found: $name");
    }
  }

  static Future<int> getDanceIdByNameAndStyle(String name, int styleId) async {
    final db = await _db();
    final result = await db.query(
      'dances',
      where: 'name = ? AND style_id = ?',
      whereArgs: [name, styleId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['id'] as int;
    } else {
      throw Exception("Dance not found: $name for style ID $styleId");
    }
  }

  static Future<Map<String, List<String>>> getStylesAndDancesFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/figures.json');
      final List<dynamic> data = json.decode(jsonString);

      Map<String, List<String>> stylesAndDances = {};

      for (var style in data) {
        final styleName = style['style'];
        final dances = style['dances'] as List<dynamic>;

        stylesAndDances[styleName] = dances.map((dance) => dance['name'] as String).toList();
      }

      return stylesAndDances;
    } catch (e) {
      if (kDebugMode) {
        print("Error reading JSON: $e");
      }
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> getCustomFiguresByStyleAndDance({
    required int styleId,
    required int danceId,
  }) async {
    final db = await _db();

    return await db.query(
      'figures',
      where: 'custom = 1 AND style_id = ? AND dance_id = ?',
      whereArgs: [styleId, danceId],
    );
  }

  // Fetch methods
  static Future<List<Map<String, dynamic>>> getAllStyles() async {
    final db = await _db();
    return await db.query('styles');
  }

  static Future<List<Map<String, dynamic>>> getAllFigures() async {
    final db = await _db();
    return await db.rawQuery('''
    SELECT 
      figures.description, 
      figures.level, 
      styles.name AS style_name, 
      dances.name AS dance_name, 
      figures.video_url, 
      figures.start, 
      figures.end 
    FROM figures
    JOIN styles ON figures.style_id = styles.id
    JOIN dances ON figures.dance_id = dances.id
    WHERE figures.description NOT IN ('Long Wall', 'Short Wall');
  ''');
  }

  static Future<List<Map<String, dynamic>>> getDancesByStyleId(int styleId) async {
    final db = await _db();
    return await db.query(
      'dances',
      columns: ['id', 'name'], // Ensure 'id' and 'name' are fetched
      where: 'style_id = ?',
      whereArgs: [styleId],
    );
  }

  static Future<List<Map<String, dynamic>>> getFigures({
    required int styleId,
    required int danceId,
    required String level,
  }) async {
    final db = await _db();

    // Check if the style is Country Western
    final isCountryWestern = await isCountryWesternStyle(styleId);

    // Level filtering for Country Western (like Intl. styles)
    final levelsToInclude = isCountryWestern
        ? (level == 'Newcomer IV'
        ? ['Newcomer IV']
        : level == 'Newcomer III'
        ? ['Newcomer IV', 'Newcomer III']
        : ['Newcomer IV', 'Newcomer III', 'Newcomer II'])  // Show all for Newcomer II
        : (level == 'Bronze'
        ? ['Bronze']
        : level == 'Silver'
        ? ['Bronze', 'Silver']
        : ['Bronze', 'Silver', 'Gold']);  // Intl. filtering logic

    if (kDebugMode) {
      print("Fetching figures for ${isCountryWestern ? 'Country Western' : 'International'} - Levels: $levelsToInclude");
    }

    // Fetch figures based on filtered levels
    return await db.query(
      'figures',
      columns: [
        'id',
        'description',
        'level',
        'video_url',
        'start',
        'end',
      ],
      where: 'style_id = ? AND dance_id = ? AND level IN (${List.filled(levelsToInclude.length, '?').join(', ')})',
      whereArgs: [styleId, danceId, ...levelsToInclude],
    );
  }

  static Future<List<Map<String, dynamic>>> getFiguresForChoreography(int choreographyId) async {
    final db = await _db();
    final result = await db.rawQuery('''
    SELECT figures.*, 
           choreography_figures.id AS choreography_figure_id,
           choreography_figures.notes AS notes,
           choreography_figures.position AS position
    FROM figures
    JOIN choreography_figures ON figures.id = choreography_figures.figure_id
    WHERE choreography_figures.choreography_id = ?
    ORDER BY choreography_figures.position ASC  -- Ensure consistent ordering
  ''', [choreographyId]);

    return List<Map<String, dynamic>>.from(result);
  }

  // Add and update methods
  static Future<int> addFigureToChoreography({
    required int choreographyId,
    required int figureId,
    String? notes, // Accept notes as an optional parameter
  }) async {
    final db = await _db();
    final maxPosition = await _getMaxPositionInChoreography(choreographyId);

    final choreographyFigureId = await db.insert('choreography_figures', {
      'choreography_id': choreographyId,
      'figure_id': figureId,
      'position': maxPosition + 1,
      'notes': notes ?? '', // Save notes if provided, otherwise default to an empty string
    });

    if (kDebugMode) {
      print("Inserted into choreography_figures with ID: $choreographyFigureId, Notes: $notes");
    }
    return choreographyFigureId;
  }

  static Future<void> updateFigureNotes(int choreographyFigureId, String notes) async {
    final db = await _db();
    int updatedRows = await db.update(
      'choreography_figures',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [choreographyFigureId],
    );

    if (kDebugMode) {
      print("Rows updated: $updatedRows");
    }
    if (updatedRows == 0) {
      if (kDebugMode) {
        print("No row found with id: $choreographyFigureId");
      }
    }
  }

  static Future<void> removeFigureFromChoreography({
    required int choreographyFigureId,
  }) async {
    final db = await _db();

    // Unlink the figure by deleting from choreography_figures
    await db.delete(
      'choreography_figures',
      where: 'id = ?',
      whereArgs: [choreographyFigureId],
    );
  }

  static Future<void> deleteCustomFigure(int figureId) async {
    final db = await _db();

    // Delete from figures and unlink from all choreographies
    await db.delete(
      'figures',
      where: 'id = ? AND custom = 1',
      whereArgs: [figureId],
    );

    await db.delete(
      'choreography_figures',
      where: 'figure_id = ?',
      whereArgs: [figureId],
    );
  }

  static Future<List<Map<String, dynamic>>> getCustomFigures() async {
    final db = await _db();

    // Query all custom figures from the figures table
    return await db.query(
      'figures',
      where: 'custom = 1',
    );
  }

  static Future<void> updateFigureOrder({
    required int choreographyFigureId,
    required int newPosition,
  }) async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.update(
        'choreography_figures',
        {'position': newPosition},
        where: 'id = ?',
        whereArgs: [choreographyFigureId],
      );
    });
  }

  static Future<Map<String, dynamic>> getChoreographyById(int choreographyId) async {
    final db = await _db();
    final result = await db.query(
      'choreographies',
      where: 'id = ?',
      whereArgs: [choreographyId],
      limit: 1, // Retrieve only one result
    );

    if (result.isEmpty) {
      throw Exception("Choreography not found with ID: $choreographyId");
    }
    return result.first;
  }

  static Future<String> getStyleNameById(int styleId) async {
    final db = await _db();
    final result = await db.query(
      'styles',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [styleId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['name'] as String;
    } else {
      throw Exception("Style not found for ID: $styleId");
    }
  }

  static Future<String> getDanceNameById(int danceId) async {
    final db = await _db();
    final result = await db.query(
      'dances',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [danceId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['name'] as String;
    } else {
      throw Exception("Dance not found for ID: $danceId");
    }
  }

  // Helper methods
  static Future<int> _getMaxPositionInChoreography(int choreographyId) async {
    final db = await _db();
    final result = await db.rawQuery(
        'SELECT MAX(position) as max_position FROM choreography_figures WHERE choreography_id = ?',
        [choreographyId]);
    return (result.first['max_position'] as int?) ?? 0;
  }

  static Future<bool> isCountryWesternStyle(int styleId) async {
    final db = await _db();
    final result = await db.query(
      'styles',
      where: 'id = ? AND name LIKE ?',
      whereArgs: [styleId, '%Country Western%'],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}
