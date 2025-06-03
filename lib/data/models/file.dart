class FileModel {
  final int? id;
  final String name;
  final String path;

  FileModel({
    this.id,
    required this.name,
    required this.path,
  });

  factory FileModel.fromMap(Map<String, dynamic> map) {
    return FileModel(
      id: map['id'],
      name: map['name'],
      path: map['path'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
    };
  }
}
