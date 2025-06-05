import 'package:music_lector/data/datasources/setlist_datasource.dart';
import 'package:music_lector/data/models/setList.dart';

class SetListRepository {
  final SetListLocalDatasource _localDatasource = SetListLocalDatasource();

  Future<void> insertSetList(SetList setList) async {
    await _localDatasource.insertSetList(setList);
  }

  Future<List<SetList>> getSetLists() async {
    return await _localDatasource.getSetLists();
  }

  Future<void> updateSetList(SetList setList) async {
    await _localDatasource.updateSetList(setList);
  }

  Future<void> deleteSetList(int id) async {
    await _localDatasource.deleteSetList(id);
  }
}
