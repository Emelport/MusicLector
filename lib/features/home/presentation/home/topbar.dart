import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:music_lector/data/models/file.dart';
import 'package:music_lector/data/repositories/file_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({Key? key}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _pickAndSaveFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: false,
      withReadStream: false,
    );
    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;

      final nameController = TextEditingController(text: fileName);

      // Mostrar modal para editar datos del archivo
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

        // Copiar el archivo al directorio de la app
        final appDir = await getApplicationDocumentsDirectory();
        final newFilePath = p.join(appDir.path, editedName);
        await File(filePath).copy(newFilePath);

        final repo = Provider.of<FileRepositoryImpl>(context, listen: false);
        await repo.insertFile(
          FileModel(id: null, name: editedName, path: newFilePath),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archivo copiado y guardado: $editedName'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Colors.blue[900]!,
          width: 1,
        ),
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
                  borderSide: BorderSide(
                    color: Colors.blue[900]!,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                    color: Colors.blue[900]!,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                    color: Colors.blue[900]!,
                    width: 2,
                  ),
                ),
                isDense: true,
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.file_open_outlined,
            color: Colors.blue[900],
          ),
          onPressed: () => _pickAndSaveFile(context),
        ),
        IconButton(
          icon: Icon(Icons.menu_outlined, color: Colors.blue[900]),
          onPressed: () {
            // Acción de importar archivos
          },
        ),
      ],
      iconTheme: const IconThemeData(color: Colors.black),
    );
  }
}
