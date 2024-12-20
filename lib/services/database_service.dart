import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static Future<Database> initializeDB() async {
    final String path = join(await getDatabasesPath(), 'choreography.db');
    return openDatabase(
      path,
      version: 25,
      onCreate: (database, version) async {
        print("Creating database...");
        await _createTables(database);
        await _insertInitialData(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        print("Upgrading database from version $oldVersion to $newVersion...");
        await _dropTables(database);
        await _createTables(database);
        await _insertInitialData(database);
        print("Database upgraded successfully.");
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
        custom BOOLEAN DEFAULT 0, -- Custom figure flag
        FOREIGN KEY(style_id) REFERENCES styles(id),
        FOREIGN KEY(dance_id) REFERENCES dances(id)
      );
    ''');
    await database.execute('''
      CREATE TABLE choreographies (
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
      CREATE TABLE choreography_figures (
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
    await database.execute("DROP TABLE IF EXISTS choreographies");
    await database.execute("DROP TABLE IF EXISTS choreography_figures");
  }

  static Future<void> _insertInitialData(Database database) async {
    print("Inserting data from JSON...");
    await _insertFiguresFromJson(database);
    print("Data successfully inserted from JSON.");
  }

  static Future<void> _insertFiguresFromJson(Database database) async {
    final String figuresJson = await rootBundle.loadString('assets/figures.json');
    final List<dynamic> stylesData = json.decode(figuresJson);

    for (var style in stylesData) {
      // Insert style
      final styleId = await database.insert('styles', {'name': style['style']});

      for (var dance in style['dances']) {
        // Insert dance
        final danceId = await database.insert('dances', {
          'style_id': styleId,
          'name': dance['name'],
        });

        // Insert figures
        final levels = dance['levels'];
        levels.forEach((level, figures) async {
          for (var figure in figures) {
            try {
              await database.insert('figures', {
                'style_id': styleId,
                'dance_id': danceId,
                'level': level,
                'description': figure['description'],
                'notes': figure['notes'] ?? '', // Default empty notes
                'video_url': figure['video_url'] ?? '', // Fallback to empty string
                'start': figure['start'] ?? 0, // Default start time to 0
                'end': figure['end'] ?? 0, // Default end time to 0
              });
            } catch (e) {
              print("Error inserting figure: ${figure['description']}, $e");
            }
          }
        });
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
    required String description,
    String notes = '',
  }) async {
    final db = await _db();

    // Insert the custom figure into the `figures` table
    final figureId = await db.insert('figures', {
      'style_id': 0, // Default or placeholder for style_id
      'dance_id': 0, // Default or placeholder for dance_id
      'level': 'Custom', // Custom level
      'description': description,
      'notes': notes,
      'custom': 1, // Mark as custom
    });

    // Link the custom figure to the choreography
    final existingLink = await db.query('choreography_figures',
        where: 'choreography_id = ? AND figure_id = ?',
        whereArgs: [choreographyId, figureId]);

    if (existingLink.isEmpty) {
      await db.insert('choreography_figures', {
        'choreography_id': choreographyId,
        'figure_id': figureId,
        'position': 0, // Add default position
      });
    }

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
      print("Error reading JSON: $e");
      return {};
    }
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
    WHERE figures.description NOT IN ('Long Wall', 'Short Wall')
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

    // Determine levels to include based on choreography level
    final levelsToInclude = level == 'Bronze'
        ? ['Bronze']
        : level == 'Silver'
        ? ['Bronze', 'Silver']
        : ['Bronze', 'Silver', 'Gold'];

    // Query figures with video details
    return await db.query(
      'figures',
      columns: [
        'id',
        'description',
        'level',
        'video_url', // Include video URL
        'start', // Include start time
        'end', // Include end time
      ],
      where: 'style_id = ? AND dance_id = ? AND level IN (${List.filled(levelsToInclude.length, '?').join(', ')})',
      whereArgs: [styleId, danceId, ...levelsToInclude],
    );
  }

  static Future<List<Map<String, dynamic>>> getFiguresForChoreography(int choreographyId) async {
    final db = await _db();
    return await db.rawQuery('''
    SELECT figures.*, choreography_figures.id AS choreography_figure_id, choreography_figures.notes
    FROM figures
    JOIN choreography_figures ON figures.id = choreography_figures.figure_id
    WHERE choreography_figures.choreography_id = ?
    ORDER BY choreography_figures.position
  ''', [choreographyId]);
  }

  // Add and update methods
  static Future<void> addFigureToChoreography({
    required int choreographyId,
    required int figureId,
  }) async {
    final db = await _db();

    // Check if the figure already exists in the choreography
    final existingLink = await db.query(
      'choreography_figures',
      where: 'choreography_id = ? AND figure_id = ?',
      whereArgs: [choreographyId, figureId],
    );

    if (existingLink.isEmpty) {
      // Add the figure only if it doesn't already exist
      final maxPosition = await _getMaxPositionInChoreography(choreographyId);
      await db.insert('choreography_figures', {
        'choreography_id': choreographyId,
        'figure_id': figureId,
        'position': maxPosition + 1,
      });
    }
  }

  static Future<void> updateFigureNotes(int choreographyFigureId, String notes) async {
    final db = await _db();
    await db.update(
      'choreography_figures',
      {'notes': notes}, // Update notes
      where: 'id = ?', // Match by choreography_figure_id
      whereArgs: [choreographyFigureId],
    );
  }

  static Future<void> removeFigureFromChoreography({
    required int choreographyFigureId,
  }) async {
    final db = await _db();
    await db.delete(
      'choreography_figures',
      where: 'id = ?',
      whereArgs: [choreographyFigureId],
    );
  }

  static Future<void> updateFigureOrder({
    required int choreographyFigureId,
    required int newPosition,
  }) async {
    final db = await _db();
    await db.update(
      'choreography_figures',
      {'position': newPosition},
      where: 'id = ?',
      whereArgs: [choreographyFigureId],
    );
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
}
