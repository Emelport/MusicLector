import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:music_lector/data/repositories/file_repository.dart';
import 'package:music_lector/data/models/file.dart';
import 'package:music_lector/core/events/file_events.dart';
import 'package:music_lector/core/utils/snackbar_utils.dart';

class PdfList extends StatefulWidget {
  const PdfList({super.key});

  @override
  State<PdfList> createState() => _PdfListState();
}

class _PdfListState extends State<PdfList> {
  Future<List<FileModel>>? _filesFuture;
  late StreamSubscription _fileUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _refreshFiles();
    _fileUpdateSubscription = FileEvents().onFileUpdate.listen((_) {
      _refreshFiles();
    });
  }

  @override
  void dispose() {
    _fileUpdateSubscription.cancel();
    super.dispose();
  }

  void _refreshFiles() {
    final repo = Provider.of<FileRepositoryImpl>(context, listen: false);
    setState(() {
      _filesFuture = repo.getFiles();
    });
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
            return ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text(
                file.name,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: null,
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(12)),
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
                                        Provider.of<FileRepositoryImpl>(context,
                                            listen: false);
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
              onTap: () {
                context.push('/pdf_viewer', extra: file.path);
              },
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              dense: true,
              selected: false,
            );
          },
        );
      },
    );
  }
}
