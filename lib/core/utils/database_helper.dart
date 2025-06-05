import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'music_files.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE files(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE setlists(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE setlist_files(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        setlist_id INTEGER,
        file_id INTEGER,
        position INTEGER,
        FOREIGN KEY(setlist_id) REFERENCES setlists(id),
        FOREIGN KEY(file_id) REFERENCES files(id)
      )
    ''');
  }

  // --- Métodos para Files ---

  Future<int> insertFile(Map<String, dynamic> values) async {
    final db = await database;
    return await db.insert('files', values);
  }

  Future<List<Map<String, dynamic>>> queryAllFiles() async {
    final db = await database;
    return await db.query('files');
  }

  Future<int> updateFile(Map<String, dynamic> values, String where,
      List<dynamic> whereArgs) async {
    final db = await database;
    return await db.update('files', values, where: where, whereArgs: whereArgs);
  }

  Future<int> deleteFile(String where, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.delete('files', where: where, whereArgs: whereArgs);
  }

  // --- Métodos para SetLists ---

  Future<int> insertSetList(
      String name, List<Map<String, dynamic>> files) async {
    final db = await database;
    final setlistId = await db.insert('setlists', {'name': name});

    for (int i = 0; i < files.length; i++) {
      await db.insert('setlist_files',
          {'setlist_id': setlistId, 'file_id': files[i]['id'], 'position': i});
    }

    return setlistId;
  }

  Future<List<Map<String, dynamic>>> queryAllSetLists() async {
    final db = await database;
    final setlists = await db.query('setlists');

    for (var setlist in setlists) {
      final setlistId = setlist['id'] as int;
      final files = await db.rawQuery('''
        SELECT files.* FROM files
        INNER JOIN setlist_files ON files.id = setlist_files.file_id
        WHERE setlist_files.setlist_id = ?
        ORDER BY setlist_files.position
      ''', [setlistId]);
      setlist['files'] = files;
    }

    return setlists;
  }

  Future<int> updateSetList(
      int setlistId, String name, List<Map<String, dynamic>> files) async {
    final db = await database;
    await db.update('setlists', {'name': name},
        where: 'id = ?', whereArgs: [setlistId]);
    await db.delete('setlist_files',
        where: 'setlist_id = ?', whereArgs: [setlistId]);

    for (int i = 0; i < files.length; i++) {
      await db.insert('setlist_files',
          {'setlist_id': setlistId, 'file_id': files[i]['id'], 'position': i});
    }

    return setlistId;
  }

  Future<int> deleteSetList(int setlistId) async {
    final db = await database;
    await db.delete('setlist_files',
        where: 'setlist_id = ?', whereArgs: [setlistId]);
    return await db.delete('setlists', where: 'id = ?', whereArgs: [setlistId]);
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
