import 'package:flutter/material.dart';

class MenuBar extends StatelessWidget {
  const MenuBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.edit, color: Colors.blue[900]),
          tooltip: 'Editar',
          onPressed: () {
            // Acción de editar
          },
        ),
        IconButton(
          icon: Icon(Icons.flag, color: Colors.blue[900]),
          tooltip: 'Bandera',
          onPressed: () {
            // Acción de bandera
          },
        ),
      ],
    );
  }
}
