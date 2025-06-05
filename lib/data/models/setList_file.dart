import 'package:music_lector/data/models/file.dart';

class SetListFile {
  final FileModel file;
  int position;

  SetListFile({
    required this.file,
    required this.position,
  });

  factory SetListFile.fromMap(Map<String, dynamic> map) {
    return SetListFile(
      file: FileModel.fromMap(map['file'] as Map<String, dynamic>),
      position: map['position'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'file': file.toMap(),
      'position': position,
    };
  }
}
