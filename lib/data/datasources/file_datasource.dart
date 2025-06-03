import 'package:music_lector/core/utils/database_helper.dart';

class FileLocalDatasource {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> insertFile(Map<String, dynamic> file) async {
    await _dbHelper.insertFile(file);
  }

  Future<List<Map<String, dynamic>>> getFiles() async {
    return await _dbHelper.queryAllFiles();
  }

  Future<void> updateFile(
      Map<String, dynamic> file, String where, List<dynamic> whereArgs) async {
    await _dbHelper.updateFile(file, where, whereArgs);
  }

  Future<void> deleteFile(String where, List<dynamic> whereArgs) async {
    await _dbHelper.deleteFile(where, whereArgs);
  }
}
