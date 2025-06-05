import 'package:music_lector/data/models/file.dart';
import 'package:music_lector/data/datasources/file_datasource.dart';

class FileRepositoryImpl {
  final FileLocalDatasource _localDatasource = FileLocalDatasource();

  Future<void> insertFile(FileModel file) async {
    await _localDatasource.insertFile(file.toMap());
  }

  Future<List<FileModel>> getFiles() async {
    final files = await _localDatasource.getFiles();
    return files.map((file) => FileModel.fromMap(file)).toList();
  }

  Future<void> updateFile(FileModel file) async {
    await _localDatasource.updateFile(file.toMap(), 'id = ?', [file.id]);
  }

  // Nuevo método flexible para borrar por cualquier campo
  Future<void> deleteFile(String where, List<dynamic> whereArgs) async {
    await _localDatasource.deleteFile(where, whereArgs);
  }
}
