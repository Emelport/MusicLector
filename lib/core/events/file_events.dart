import 'dart:async';

class FileEvents {
  static final FileEvents _instance = FileEvents._internal();
  factory FileEvents() => _instance;
  FileEvents._internal();

  final _fileUpdateController = StreamController<void>.broadcast();
  Stream<void> get onFileUpdate => _fileUpdateController.stream;

  void notifyFileUpdate() {
    _fileUpdateController.add(null);
  }

  void dispose() {
    _fileUpdateController.close();
  }
}
