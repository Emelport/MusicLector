import 'package:music_lector/core/utils/database_helper.dart';
import 'package:music_lector/data/models/file.dart';
import 'package:music_lector/data/models/setlist.dart';
import 'package:music_lector/data/models/setlist_file.dart';

class SetListLocalDatasource {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> insertSetList(SetList setList) async {
    final db = await _dbHelper.database;

    final setListId = await db.insert('setlists', {
      'name': setList.name,
    });

    for (var file in setList.files) {
      await db.insert('setlist_files', {
        'setlist_id': setListId,
        'file_id': file.file.id,
        'position': file.position,
      });
    }
  }

  Future<List<SetList>> getSetLists() async {
    final db = await _dbHelper.database;
    final setlists = await db.query('setlists');

    return Future.wait(setlists.map((setlistMap) async {
      final id = setlistMap['id'] as int;

      final rows = await db.rawQuery('''
        SELECT sf.position, f.id, f.name, f.path
        FROM setlist_files sf
        JOIN files f ON f.id = sf.file_id
        WHERE sf.setlist_id = ?
        ORDER BY sf.position ASC
      ''', [id]);

      final files = rows.map((row) {
        return SetListFile(
          file: FileModel(
            id: row['id'] as int,
            name: row['name'] as String,
            path: row['path'] as String,
          ),
          position: row['position'] as int,
        );
      }).toList();

      return SetList(
        id: id,
        name: setlistMap['name'] as String,
        files: files,
      );
    }).toList());
  }

  Future<void> updateSetList(SetList setList) async {
    final db = await _dbHelper.database;

    await db.update(
      'setlists',
      {'name': setList.name},
      where: 'id = ?',
      whereArgs: [setList.id],
    );

    await db.delete('setlist_files',
        where: 'setlist_id = ?', whereArgs: [setList.id]);

    for (var file in setList.files) {
      await db.insert('setlist_files', {
        'setlist_id': setList.id,
        'file_id': file.file.id,
        'position': file.position,
      });
    }
  }

  Future<void> deleteSetList(int id) async {
    final db = await _dbHelper.database;

    await db.delete('setlist_files', where: 'setlist_id = ?', whereArgs: [id]);
    await db.delete('setlists', where: 'id = ?', whereArgs: [id]);
  }
}
