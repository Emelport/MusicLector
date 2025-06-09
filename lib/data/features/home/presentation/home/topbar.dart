import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_lector/data/models/file.dart';
import 'package:music_lector/data/repositories/file_repository.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:music_lector/core/utils/snackbar_utils.dart';
import 'package:music_lector/core/events/file_events.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({Key? key}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  /// Entra en pantalla completa y sale al presionar ESC.

  Future<String> getStorageFolderPath() async {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final storageFolder = Directory(p.join(exeDir.path, 'musicPDF'));

    if (!await storageFolder.exists()) {
      await storageFolder.create(recursive: true);
    }

    return storageFolder.path;
  }

  Future<void> _pickAndSaveFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;
      final nameController = TextEditingController(text: fileName);

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Editar datos del archivo'),
            content: TextField(
              controller: nameController,
              decoration:
                  const InputDecoration(labelText: 'Nombre del archivo'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        final editedName = nameController.text.trim().isEmpty
            ? fileName
            : nameController.text.trim();

        final folderPath = await getStorageFolderPath();
        final newFilePath = p.join(folderPath, editedName);

        await File(filePath).copy(newFilePath);

        final repo = Provider.of<FileRepositoryImpl>(context, listen: false);
        await repo.insertFile(
          FileModel(id: null, name: editedName, path: newFilePath),
        );

        SnackbarUtils.showMessage(
          context,
          'Archivo copiado y guardado: $editedName',
        );

        // Notify about file changes
        FileEvents().notifyFileUpdate();
      }
    }
  }

  Future<void> _syncFilesWithFolder(BuildContext context) async {
    final folderPath = await getStorageFolderPath();
    final folder = Directory(folderPath);
    final filesInFolder = folder
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList();

    final fileRepo = Provider.of<FileRepositoryImpl>(context, listen: false);
    final dbFiles = await fileRepo.getFiles();

    final dbPaths = dbFiles.map((f) => f.path).toSet();
    final folderPaths = filesInFolder.map((f) => f.path).toSet();

    final newFiles = filesInFolder.where((f) => !dbPaths.contains(f.path));
    for (final file in newFiles) {
      await fileRepo.insertFile(FileModel(
        name: p.basename(file.path),
        path: file.path,
      ));
    }

    final removedFiles = dbFiles.where((f) => !folderPaths.contains(f.path));
    for (final file in removedFiles) {
      if (file.id != null) {
        await fileRepo.deleteFile('id = ?', [file.id]);
      }
    }

    // Notify about file changes
    FileEvents().notifyFileUpdate();

    SnackbarUtils.showMessage(
      context,
      'Archivos sincronizados',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.blue[900]!, width: 1),
        borderRadius: BorderRadius.zero,
      ),
      elevation: 1,
      title: const Text(
        'Music Lector',
        style: TextStyle(color: Colors.black),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: SizedBox(
            width: 180,
            child: TextField(
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
                hintText: 'Buscar',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.blue[900]!, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.blue[900]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.blue[900]!, width: 2),
                ),
                isDense: true,
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.file_open_outlined, color: Colors.blue[900]),
          onPressed: () => _pickAndSaveFile(context),
        ),
        IconButton(
          icon: Icon(Icons.folder_open, color: Colors.blue[900]),
          tooltip: 'Abrir carpeta de archivos',
          onPressed: () async {
            final folderPath = await getStorageFolderPath();
            if (Platform.isWindows) {
              await Process.run('explorer', [folderPath]);
            } else if (Platform.isMacOS) {
              await Process.run('open', [folderPath]);
            } else if (Platform.isLinux) {
              await Process.run('xdg-open', [folderPath]);
            }
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.menu_outlined, color: Colors.blue[900]),
          onSelected: (value) async {
            bool isFullScreen = await windowManager.isFullScreen();

            switch (value) {
              case 'fullscreen':
                if (!isFullScreen) {
                  await windowManager.setFullScreen(true);
                  await windowManager.setResizable(false);
                  // Oculta la barra de título si es posible
                  await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
                } else {
                  await windowManager.setFullScreen(false);
                  await windowManager.setResizable(true);
                  await windowManager.setTitleBarStyle(TitleBarStyle.normal);
                  await windowManager.setSize(const Size(1200, 800));
                  await windowManager.center();
                  await windowManager.show();
                  await windowManager.focus();
                  (context as Element).markNeedsBuild();
                }
                break;

              case 'windows':
                if (isFullScreen) {
                  await windowManager.setFullScreen(false);
                  await windowManager.setResizable(true);
                  // Set a reasonable default size when exiting fullscreen
                  await windowManager.setSize(const Size(1200, 800));
                  await windowManager.center();
                  await windowManager.show();
                  await windowManager.focus();
                  // Optionally, force a rebuild if your layout does not update automatically
                  // (Uncomment the next line if needed)
                  (context as Element).markNeedsBuild();
                }
                break;

              case 'exit':
                if (Platform.isWindows ||
                    Platform.isLinux ||
                    Platform.isMacOS) {
                  await windowManager.close();
                } else {
                  // For other platforms, you might want to use exit(0) or similar
                  exit(0);
                }
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'fullscreen',
              child: Text('Pantalla completa'),
            ),
            PopupMenuItem(
              value: 'windows',
              child: Text('Ventana'),
            ),
            PopupMenuItem(
              value: 'exit',
              child: Text('Cerrar Aplicacion'),
            ),
          ],
        ),
        IconButton(
          icon: Icon(Icons.sync_outlined, color: Colors.blue[900]),
          tooltip: 'Recargar archivos',
          onPressed: () async {
            await _syncFilesWithFolder(context);
          },
        ),
      ],
      iconTheme: const IconThemeData(color: Colors.black),
    );
  }
}
