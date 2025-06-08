import 'package:flutter/material.dart';
import 'package:music_lector/data/datasources/setList_datasource.dart';
import 'package:music_lector/data/models/setlist.dart';
import 'package:music_lector/data/models/setlist_file.dart';
import 'package:music_lector/data/repositories/file_repository.dart';
import 'package:music_lector/data/features/lector/presentation/pdf_viewer.dart';

class SetListMenu extends StatefulWidget {
  const SetListMenu({Key? key}) : super(key: key);

  @override
  State<SetListMenu> createState() => _SetListMenuState();
}

class _SetListMenuState extends State<SetListMenu> {
  List<SetList> _setLists = [];
  SetList? _selectedSetList;
  bool _isEditing = false;
  late TextEditingController _nameController;

  final SetListLocalDatasource _datasource = SetListLocalDatasource();
  final FileRepositoryImpl _fileRepository = FileRepositoryImpl();

  @override
  void initState() {
    super.initState();
    _loadSetLists();
  }

  Future<void> _loadSetLists() async {
    final lists = await _datasource.getSetLists();
    setState(() {
      _setLists = lists;
    });
  }

  void _selectSetList(SetList setList) {
    setState(() {
      _selectedSetList = SetList(
        id: setList.id,
        name: setList.name,
        files: List.from(setList.files),
      );
      _nameController = TextEditingController(text: _selectedSetList!.name);
      _isEditing = false;
    });
  }

  Future<void> _saveChanges() async {
    if (_selectedSetList != null) {
      setState(() {
        _selectedSetList!.name = _nameController.text;
        _isEditing = false;
      });
      await _datasource.updateSetList(_selectedSetList!);
      await _loadSetLists();
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (!_isEditing || _selectedSetList == null) return;

    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      _selectedSetList!.moveFile(oldIndex, newIndex);
    });
  }

  Future<void> _createNewSetList() async {
    final newSetList = SetList(
      id: 0, // lo asigna la DB
      name: "Nuevo SetList",
      files: [],
    );
    await _datasource.insertSetList(newSetList);
    await _loadSetLists();
  }

  Future<void> _deleteSelectedSetList() async {
    if (_selectedSetList == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Eliminar SetList"),
        content: Text(
            "¿Estás seguro de que quieres eliminar '${_selectedSetList!.name}'?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Eliminar")),
        ],
      ),
    );

    if (confirm == true) {
      await _datasource.deleteSetList(_selectedSetList!.id!);
      setState(() => _selectedSetList = null);
      await _loadSetLists();
    }
  }

  Future<void> _addFilesToSetList() async {
    final files = await _fileRepository.getFiles();
    final alreadyAddedIds =
        _selectedSetList!.files.map((f) => f.file.id).toSet();
    final selectedFiles = <int?>{};

    final selected = await showDialog<List>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.library_music,
                        color: Colors.blue[800], size: 28),
                    const SizedBox(width: 10),
                    const Text(
                      'Selecciona archivos',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, null),
                    ),
                  ],
                ),
                const Divider(height: 20),
                SizedBox(
                  height: 320,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView(
                      children: files.map<Widget>((file) {
                        final alreadyAdded = alreadyAddedIds.contains(file.id);
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 2, horizontal: 0),
                          elevation: 1,
                          child: CheckboxListTile(
                            value:
                                alreadyAdded || selectedFiles.contains(file.id),
                            onChanged: alreadyAdded
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v == true) {
                                        selectedFiles.add(file.id);
                                      } else {
                                        selectedFiles.remove(file.id);
                                      }
                                    });
                                    (context as Element).markNeedsBuild();
                                  },
                            title: Text(file.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            controlAffinity: ListTileControlAffinity.leading,
                            secondary: alreadyAdded
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context, null),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: selectedFiles.isEmpty
                          ? null
                          : () {
                              final selectedList = files
                                  .where((f) => selectedFiles.contains(f.id))
                                  .toList();
                              Navigator.pop(context, selectedList);
                            },
                      icon: const Icon(Icons.link),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        for (var file in selected) {
          _selectedSetList!.files.add(SetListFile(
              file: file, position: _selectedSetList!.files.length));
        }
      });
      await _datasource.updateSetList(_selectedSetList!);
      await _loadSetLists();
    }
  }

  Future<void> _removeFileFromSetList(int index) async {
    setState(() {
      _selectedSetList!.files.removeAt(index);
    });
    await _datasource.updateSetList(_selectedSetList!);
    await _loadSetLists();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Minimalista lista de SetLists
        Container(
          width: 160,
          color: Colors.blue[900]?.withOpacity(0.04),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4),
                child: IconButton(
                  icon: Icon(Icons.add, color: Colors.blue[900], size: 28),
                  tooltip: "Nuevo SetList",
                  onPressed: _createNewSetList,
                  splashRadius: 22,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: _setLists.map((setList) {
                    final selected = _selectedSetList?.id == setList.id;
                    return Material(
                      color: selected
                          ? Colors.blue[900]?.withOpacity(0.12)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectSetList(setList),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.library_music,
                                color: selected
                                    ? Colors.blue[900]
                                    : Colors.blueGrey[300],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  setList.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.blue[900]
                                        : Colors.blueGrey[900],
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: Colors.blue[900]?.withOpacity(0.08)),
        // Info del SetList
        Expanded(
          child: _selectedSetList == null
              ? Center(
                  child: Text(
                    "Selecciona un SetList",
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _isEditing
                                ? TextField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "Nombre del SetList",
                                    ),
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900]),
                                    autofocus: true,
                                  )
                                : Text(
                                    _selectedSetList!.name,
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900]),
                                  ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isEditing ? Icons.check : Icons.edit,
                              color: Colors.blue[900],
                            ),
                            tooltip: _isEditing ? "Guardar" : "Editar",
                            onPressed: () {
                              if (_isEditing) {
                                _saveChanges();
                              } else {
                                setState(() => _isEditing = true);
                              }
                            },
                            splashRadius: 20,
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: Colors.blue[900]),
                            tooltip: "Eliminar",
                            onPressed: _deleteSelectedSetList,
                            splashRadius: 20,
                          ),
                          IconButton(
                            icon:
                                Icon(Icons.add_circle, color: Colors.blue[900]),
                            tooltip: "Agregar archivos",
                            onPressed: _selectedSetList == null
                                ? null
                                : _addFilesToSetList,
                            splashRadius: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _selectedSetList!.files.isEmpty
                            ? Center(
                                child: Text(
                                  "No hay archivos.",
                                  style: TextStyle(
                                      color: Colors.blue[900], fontSize: 16),
                                ),
                              )
                            : ReorderableListView.builder(
                                itemCount: _selectedSetList!.files.length,
                                onReorder: (oldIndex, newIndex) async {
                                  if (!_isEditing) return;
                                  setState(() {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    final item = _selectedSetList!.files
                                        .removeAt(oldIndex);
                                    _selectedSetList!.files
                                        .insert(newIndex, item);
                                    for (int i = 0;
                                        i < _selectedSetList!.files.length;
                                        i++) {
                                      _selectedSetList!.files[i].position = i;
                                    }
                                  });
                                  await _datasource
                                      .updateSetList(_selectedSetList!);
                                  await _loadSetLists();
                                },
                                buildDefaultDragHandles: false,
                                itemBuilder: (context, index) {
                                  final file = _selectedSetList!.files[index];
                                  return Material(
                                    key: ValueKey(file.file.id),
                                    color: Colors.transparent,
                                    child: ListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 0, vertical: 0),
                                      title: Text(
                                        file.file.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: Colors.blueGrey[900],
                                            fontWeight: FontWeight.w500),
                                      ),
                                      trailing: _isEditing
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ReorderableDragStartListener(
                                                  index: index,
                                                  child: Icon(Icons.drag_handle,
                                                      color: Colors.blue[900],
                                                      size: 20),
                                                ),
                                              ],
                                            )
                                          : null,
                                      leading: _isEditing
                                          ? IconButton(
                                              icon: Icon(Icons.remove_circle,
                                                  color: Colors.blue[900],
                                                  size: 20),
                                              onPressed: () =>
                                                  _removeFileFromSetList(index),
                                              splashRadius: 18,
                                            )
                                          : Icon(Icons.picture_as_pdf,
                                              color: Colors.blue[900],
                                              size: 20),
                                      onTap: () async {
                                        final filePaths = _selectedSetList!
                                            .files
                                            .map((f) => f.file.path)
                                            .toList();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PdfViewer(
                                              filePath: filePaths.join(';|;'),
                                              multipleFiles: true,
                                              indexStart: index,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
