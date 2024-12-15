import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static Future<Database> initializeDB() async {
    final String path = join(await getDatabasesPath(), 'choreography.db');
    return openDatabase(
      path,
      version: 5,
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
    // Create all necessary tables
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
      CREATE TABLE figures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        style_id INTEGER NOT NULL,
        dance_id INTEGER NOT NULL,
        level TEXT NOT NULL,
        description TEXT NOT NULL,
        notes TEXT DEFAULT '',
        FOREIGN KEY(style_id) REFERENCES styles(id),
        FOREIGN KEY(dance_id) REFERENCES dances(id)
      );
    ''');
    await database.execute('''
      CREATE TABLE choreography_figures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        choreography_id INTEGER NOT NULL,
        figure_id INTEGER NOT NULL,
        notes TEXT DEFAULT '',
        position INTEGER NOT NULL,
        FOREIGN KEY(choreography_id) REFERENCES choreographies(id),
        FOREIGN KEY(figure_id) REFERENCES figures(id)
      );
    ''');
  }

  static Future<void> _dropTables(Database database) async {
    // Drop all tables if needed
    await database.execute("DROP TABLE IF EXISTS styles");
    await database.execute("DROP TABLE IF EXISTS dances");
    await database.execute("DROP TABLE IF EXISTS choreographies");
    await database.execute("DROP TABLE IF EXISTS figures");
    await database.execute("DROP TABLE IF EXISTS choreography_figures");
  }

  static Future<void> _insertInitialData(Database database) async {
    print("Inserting initial data...");
    // Insert styles
    await database.insert('styles', {'name': 'International Standard'});
    await database.insert('styles', {'name': 'International Latin'});

    // Insert dances
    await database.insert('dances', {'style_id': 1, 'name': 'Waltz'});
    await database.insert('dances', {'style_id': 1, 'name': 'Tango'});
    await database.insert('dances', {'style_id': 1, 'name': 'Viennese Waltz'});
    await database.insert('dances', {'style_id': 1, 'name': 'Foxtrot'});
    await database.insert('dances', {'style_id': 1, 'name': 'Quickstep'});
    await database.insert('dances', {'style_id': 2, 'name': 'Cha Cha'});
    await database.insert('dances', {'style_id': 2, 'name': 'Rumba'});
    await database.insert('dances', {'style_id': 2, 'name': 'Samba'});
    await database.insert('dances', {'style_id': 2, 'name': 'Paso Doble'});
    await database.insert('dances', {'style_id': 2, 'name': 'Jive'});

    // Insert figures
    await _insertInitialFigures(database);
    print("Initial data inserted.");
  }

  static Future<void> _insertInitialFigures(Database database) async {
    await database.insert('figures', {
      'style_id': 1,
      'dance_id': 1,
      'level': 'Bronze',
      'description': 'Natural Turn',
    });
    await database.insert('figures', {
      'style_id': 1,
      'dance_id': 1,
      'level': 'Bronze',
      'description': 'Reverse Turn',
    });
    await database.insert('figures', {
      'style_id': 1,
      'dance_id': 1,
      'level': 'Bronze',
      'description': 'Closed Change',
    });
    print("Predefined figures inserted.");
  }

  static Future<Database> _db() => initializeDB();

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
    required int styleId,
    required int danceId,
    required String level,
  }) async {
    final db = await _db();
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

  static Future<void> addFigureToChoreographyAsNewEntry({
    required int choreographyId,
    required int figureId,
  }) async {
    final db = await _db();

    // Get the max position for the current choreography
    final maxPosition = await _getMaxPositionInChoreography(choreographyId);

    // Add the figure as a new entry with a unique ID
    await db.insert('choreography_figures', {
      'choreography_id': choreographyId,
      'figure_id': figureId,
      'notes': '', // Default empty notes
      'position': maxPosition + 1, // Append at the end
    });
  }


  // Fetch methods
  static Future<List<Map<String, dynamic>>> getAllStyles() async {
    final db = await _db();
    return await db.query('styles');
  }

  static Future<List<Map<String, dynamic>>> getDancesByStyleId(int styleId) async {
    final db = await _db();
    return await db.query('dances', where: 'style_id = ?', whereArgs: [styleId]);
  }

  static Future<List<Map<String, dynamic>>> getFigures({
    required int styleId,
    required int danceId,
    required String level,
  }) async {
    final db = await _db();
    return await db.query(
      'figures',
      where: 'style_id = ? AND dance_id = ? AND level = ?',
      whereArgs: [styleId, danceId, level],
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
    final maxPosition = await _getMaxPositionInChoreography(choreographyId);
    await db.insert('choreography_figures', {
      'choreography_id': choreographyId,
      'figure_id': figureId,
      'position': maxPosition + 1,
      'notes': '', // Start with empty notes
    });
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
      where: 'id = ?', // Use choreography_figure_id
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
      where: 'id = ?', // Use choreography_figure_id
      whereArgs: [choreographyFigureId],
    );
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
