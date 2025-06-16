  import 'setlist_file.dart';

  class SetList {
    final int? id;
    String name;
    List<SetListFile> files;

    SetList({
      this.id,
      required this.name,
      required this.files,
    }) {
      _sortFiles();
    }

    factory SetList.fromMap(Map<String, dynamic> map) {
      return SetList(
        id: map['id'] as int?,
        name: map['name'] as String,
        files: (map['files'] as List<dynamic>)
            .map(
                (fileMap) => SetListFile.fromMap(fileMap as Map<String, dynamic>))
            .toList(),
      );
    }

    Map<String, dynamic> toMap() {
      return {
        'id': id,
        'name': name,
        'files': files.map((f) => f.toMap()).toList(),
      };
    }

    void moveFile(int oldIndex, int newIndex) {
      if (oldIndex < 0 || oldIndex >= files.length) return;
      final item = files.removeAt(oldIndex);
      files.insert(newIndex.clamp(0, files.length), item);
      _reassignPositions();
    }

    void _reassignPositions() {
      for (int i = 0; i < files.length; i++) {
        files[i].position = i;
      }
    }

    void _sortFiles() {
      files.sort((a, b) => a.position.compareTo(b.position));
    }
  }
