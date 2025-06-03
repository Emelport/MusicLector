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
    // Example table
    await db.execute('''
      CREATE TABLE files(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        path TEXT
      )
    ''');
  }

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

  Future close() async {
    final db = await database;
    db.close();
  }
}
