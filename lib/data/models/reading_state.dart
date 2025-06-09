class ReadingState {
  final int fileId;
  final int lastPage;
  final DateTime lastRead;

  ReadingState({
    required this.fileId,
    required this.lastPage,
    required this.lastRead,
  });

  factory ReadingState.fromMap(Map<String, dynamic> map) {
    return ReadingState(
      fileId: map['file_id'] as int,
      lastPage: map['last_page'] as int,
      lastRead: DateTime.parse(map['last_read'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'file_id': fileId,
      'last_page': lastPage,
      'last_read': lastRead.toIso8601String(),
    };
  }
}
