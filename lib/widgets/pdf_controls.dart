import 'package:flutter/material.dart';
import 'package:music_lector/data/models/pdf_documents.dart';

class PdfControls extends StatelessWidget {
  final PdfDocumentModel documentModel;
  final Alignment alignment;
  final Future<void> Function()? onOpenBookmarkModal;
  final VoidCallback? onCloseBookmarkModal;

  const PdfControls({
    super.key,
    required this.documentModel,
    required this.alignment,
    this.onOpenBookmarkModal,
    this.onCloseBookmarkModal,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onPanUpdate: (details) => _handleToolbarDrag(details, context),
        child: Container(
          margin: const EdgeInsets.only(top: 24),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.blue[900]),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              ),
              IconButton(
                icon: Icon(Icons.edit_document, color: Colors.blue[900]),
                tooltip: 'Edit',
                onPressed: () => documentModel.toggleEditing(true),
              ),
              IconButton(
                icon:
                    Icon(Icons.bookmark_add_outlined, color: Colors.blue[900]),
                tooltip: 'Add Bookmark',
                onPressed: () async {
                  if (onOpenBookmarkModal != null) await onOpenBookmarkModal!();
                  final currentPage =
                      documentModel.stateNotifier.value.currentPage;
                  final bookmarks = documentModel.bookmarks;
                  await showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (context) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Marcadores',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 8),
                            if (bookmarks.isEmpty)
                              const Text('No hay marcadores'),
                            if (bookmarks.isNotEmpty)
                              ...bookmarks.asMap().entries.map((entry) {
                                final i = entry.key;
                                final b = entry.value;
                                return ListTile(
                                  title: Text(b.name),
                                  subtitle: b.fromPage == b.toPage
                                      ? Text('Página ${b.fromPage}')
                                      : Text(
                                          'Páginas ${b.fromPage} - ${b.toPage}'),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await documentModel.goToBookmark(i);
                                  },
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        tooltip: 'Editar',
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final totalPages = documentModel
                                              .stateNotifier.value.totalPages;
                                          final TextEditingController
                                              nameController =
                                              TextEditingController(
                                                  text: b.name);
                                          final TextEditingController
                                              fromController =
                                              TextEditingController(
                                                  text: b.fromPage.toString());
                                          final TextEditingController
                                              toController =
                                              TextEditingController(
                                                  text: b.toPage.toString());
                                          final result = await showDialog<
                                              Map<String, dynamic>>(
                                            context: context,
                                            builder: (context) =>
                                                StatefulBuilder(
                                              builder: (context, setState) =>
                                                  AlertDialog(
                                                title: const Text(
                                                    'Editar marcador'),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    TextField(
                                                      controller:
                                                          nameController,
                                                      autofocus: true,
                                                      decoration:
                                                          const InputDecoration(
                                                              hintText:
                                                                  'Nombre del marcador'),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      children: [
                                                        const Text('Desde:'),
                                                        const SizedBox(
                                                            width: 8),
                                                        SizedBox(
                                                          width: 60,
                                                          child: TextField(
                                                            controller:
                                                                fromController,
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            decoration: const InputDecoration(
                                                                isDense: true,
                                                                contentPadding:
                                                                    EdgeInsets.symmetric(
                                                                        vertical:
                                                                            6,
                                                                        horizontal:
                                                                            6)),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 16),
                                                        const Text('Hasta:'),
                                                        const SizedBox(
                                                            width: 8),
                                                        SizedBox(
                                                          width: 60,
                                                          child: TextField(
                                                            controller:
                                                                toController,
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            decoration: const InputDecoration(
                                                                isDense: true,
                                                                contentPadding:
                                                                    EdgeInsets.symmetric(
                                                                        vertical:
                                                                            6,
                                                                        horizontal:
                                                                            6)),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child:
                                                        const Text('Cancelar'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      final name =
                                                          nameController.text
                                                              .trim();
                                                      final from = int.tryParse(
                                                              fromController
                                                                  .text) ??
                                                          b.fromPage;
                                                      final to = int.tryParse(
                                                              toController
                                                                  .text) ??
                                                          b.toPage;
                                                      if (name.isNotEmpty &&
                                                          from >= 1 &&
                                                          to >= from &&
                                                          to <= totalPages) {
                                                        Navigator.pop(context, {
                                                          'name': name,
                                                          'from': from,
                                                          'to': to
                                                        });
                                                      }
                                                    },
                                                    child:
                                                        const Text('Guardar'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                          if (result != null &&
                                              result['name'] != null &&
                                              result['name'].isNotEmpty) {
                                            documentModel.renameBookmark(
                                                i, result['name']);
                                            documentModel.removeBookmark(i);
                                            documentModel.addBookmarkWithRange(
                                                result['name'],
                                                result['from'],
                                                result['to']);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content:
                                                      Text('Marcador editado')),
                                            );
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon:
                                            const Icon(Icons.delete, size: 20),
                                        tooltip: 'Eliminar',
                                        onPressed: () async {
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text(
                                                  'Eliminar marcador'),
                                              content: b.fromPage == b.toPage
                                                  ? Text(
                                                      '¿Eliminar marcador "${b.name}" de la página ${b.fromPage}?')
                                                  : Text(
                                                      '¿Eliminar marcador "${b.name}" de las páginas ${b.fromPage} - ${b.toPage}?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancelar'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('Eliminar'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            documentModel.removeBookmark(i);
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Marcador eliminado')),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            const Divider(),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar marcador'),
                              onPressed: () async {
                                Navigator.pop(context);
                                final totalPages = documentModel
                                    .stateNotifier.value.totalPages;
                                final currentPage = documentModel
                                    .stateNotifier.value.currentPage;
                                int fromPage = currentPage;
                                int toPage = currentPage;
                                final TextEditingController controller =
                                    TextEditingController();
                                final TextEditingController fromController =
                                    TextEditingController(
                                        text: currentPage.toString());
                                final TextEditingController toController =
                                    TextEditingController(
                                        text: currentPage.toString());
                                final orientation =
                                    MediaQuery.of(context).orientation;
                                final result =
                                    await showDialog<Map<String, dynamic>>(
                                  context: context,
                                  builder: (context) => StatefulBuilder(
                                    builder: (context, setState) => AlertDialog(
                                      title:
                                          const Text('Nuevo marcador (rango)'),
                                      content: SizedBox(
                                        width: 320,
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                controller: controller,
                                                autofocus: true,
                                                decoration: const InputDecoration(
                                                    hintText:
                                                        'Ej: Intro, Solo, Final...'),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  const Text('Desde:'),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 60,
                                                    child: TextField(
                                                      controller:
                                                          fromController,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration:
                                                          const InputDecoration(
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    vertical: 6,
                                                                    horizontal:
                                                                        6),
                                                      ),
                                                      onChanged: (val) {
                                                        final n =
                                                            int.tryParse(val);
                                                        if (n != null &&
                                                            n >= 1 &&
                                                            n <= totalPages) {
                                                          fromPage = n;
                                                          if (toPage <
                                                              fromPage) {
                                                            toPage = fromPage;
                                                            toController.text =
                                                                fromPage
                                                                    .toString();
                                                          }
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  const Text('Hasta:'),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 60,
                                                    child: TextField(
                                                      controller: toController,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration:
                                                          const InputDecoration(
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    vertical: 6,
                                                                    horizontal:
                                                                        6),
                                                      ),
                                                      onChanged: (val) {
                                                        final n =
                                                            int.tryParse(val);
                                                        if (n != null &&
                                                            n >= fromPage &&
                                                            n <= totalPages) {
                                                          toPage = n;
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (orientation ==
                                                  Orientation.landscape)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 8.0),
                                                  child: Text(
                                                    'En modo horizontal, los saltos de página y el rango consideran de 2 en 2 páginas.',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Colors.grey[700]),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancelar'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            final name = controller.text.trim();
                                            final nFrom = int.tryParse(
                                                    fromController.text) ??
                                                fromPage;
                                            final nTo = int.tryParse(
                                                    toController.text) ??
                                                toPage;
                                            if (name.isNotEmpty &&
                                                nFrom >= 1 &&
                                                nTo >= nFrom &&
                                                nTo <= totalPages) {
                                              Navigator.pop(context, {
                                                'name': name,
                                                'from': nFrom,
                                                'to': nTo,
                                              });
                                            }
                                          },
                                          child: const Text('Guardar'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                if (result != null &&
                                    result['name'] != null &&
                                    result['name'].isNotEmpty) {
                                  documentModel.addBookmarkWithRange(
                                      result['name'],
                                      result['from'],
                                      result['to']);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Marcador "${result['name']}" guardado de página ${result['from']} a ${result['to']}')),
                                  );
                                }
                                if (onCloseBookmarkModal != null)
                                  onCloseBookmarkModal!();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ).then((_) {
                    if (onCloseBookmarkModal != null) onCloseBookmarkModal!();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleToolbarDrag(DragUpdateDetails details, BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);
    final double x = (localPosition.dx / box.size.width) * 2 - 1;
    final double y = (localPosition.dy / box.size.height) * 2 - 1;

    double snapThreshold = 0.92;
    double snappedDx = x.clamp(-1.0, 1.0);
    if (snappedDx <= -snapThreshold)
      snappedDx = -1.0;
    else if (snappedDx >= snapThreshold) snappedDx = 1.0;

    documentModel
        .updateToolbarAlignment(Alignment(snappedDx, y.clamp(-1.0, 1.0)));
  }
}
