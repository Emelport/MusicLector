import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_lector/data/models/drawing_point.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_lector/data/repositories/file_repository.dart';
import 'package:music_lector/data/models/file.dart';
import 'package:music_lector/core/events/file_events.dart';
import 'package:music_lector/core/utils/snackbar_utils.dart';

class PdfLastViewed {
  static Future<void> saveLastPage(String filePath, int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_page_$filePath', page);
  }

  static Future<int> getLastPage(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_page_$filePath') ?? 0;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('last_page_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

class PdfBookmark {
  final String name;
  final int page;
  PdfBookmark({required this.name, required this.page});

  Map<String, dynamic> toJson() => {'name': name, 'page': page};
  factory PdfBookmark.fromJson(Map<String, dynamic> json) =>
      PdfBookmark(name: json['name'], page: json['page']);
}

class PdfConfig {
  List<PdfBookmark> bookmarks;
  Map<int, List<DrawingPoint>> drawings;

  PdfConfig({required this.bookmarks, required this.drawings});

  Map<String, dynamic> toJson() => {
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
        'drawings': drawings.map((k, v) =>
            MapEntry(k.toString(), v.map((p) => p.toJson()).toList())),
      };

  factory PdfConfig.fromJson(Map<String, dynamic> json) => PdfConfig(
        bookmarks: (json['bookmarks'] as List)
            .map((b) => PdfBookmark.fromJson(b))
            .toList(),
        drawings: (json['drawings'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(int.parse(k),
              (v as List).map((p) => DrawingPoint.fromJson(p)).toList()),
        ),
      );
}

class PdfList extends StatefulWidget {
  const PdfList({super.key});

  @override
  State<PdfList> createState() => _PdfListState();
}

class _PdfListState extends State<PdfList> {
  Future<List<FileModel>>? _filesFuture;
  late StreamSubscription _fileUpdateSubscription;
  final Map<String, int> _lastViewedPagesCache = {};

  @override
  void initState() {
    super.initState();
    _refreshFiles();
    _fileUpdateSubscription = FileEvents().onFileUpdate.listen((_) {
      _refreshFiles();
    });

    // Precargar las últimas páginas vistas
    _loadLastViewedPages();
  }

  Future<void> _loadLastViewedPages() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('last_page_'));
    for (final key in keys) {
      final filePath = key.replaceFirst('last_page_', '');
      _lastViewedPagesCache[filePath] = prefs.getInt(key) ?? 0;
    }
  }

  void _refreshFiles() async {
    final repo = Provider.of<FileRepositoryImpl>(context, listen: false);
    setState(() {
      _filesFuture = repo.getFiles();
    });
    await _loadLastViewedPages();
    setState(() {});
  }

  @override
  void dispose() {
    _fileUpdateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FileModel>>(
      future: _filesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final files = snapshot.data!;
        return ListView.separated(
          itemCount: files.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final file = files[index];
            final lastPage = _lastViewedPagesCache[file.path] ?? 0;
            final hasLastPage = lastPage > 0;

            return ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text(
                file.name,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: hasLastPage
                  ? Text('Última página vista: ${lastPage + 1}')
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    builder: (context) {
                      final nameController =
                          TextEditingController(text: file.name);
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    final repo =
                                        Provider.of<FileRepositoryImpl>(
                                      context,
                                      listen: false,
                                    );
                                    repo.updateFile(FileModel(
                                      id: file.id,
                                      name: nameController.text,
                                      path: file.path,
                                    ));
                                    Navigator.pop(context);
                                    _refreshFiles();
                                    SnackbarUtils.showMessage(
                                      context,
                                      'Nombre actualizado: ${nameController.text}',
                                    );
                                  },
                                  child: const Text('Guardar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              onTap: () async {
                await context.push('/pdf_viewer', extra: file.path);
                _refreshFiles();
              },
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              dense: true,
              selected: false,
            );
          },
        );
      },
    );
  }
}
