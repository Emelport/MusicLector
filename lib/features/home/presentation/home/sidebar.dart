import 'package:flutter/material.dart';
import 'package:music_lector/features/home/presentation/home/home_screen.dart';

class Sidebar extends StatelessWidget {
  final Function(HomeSection) onSectionSelected;
  final HomeSection selectedSection;

  const Sidebar({
    Key? key,
    required this.onSectionSelected,
    required this.selectedSection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Colors.blue[900]!,
            width: 1,
          ),
          bottom: BorderSide(
            color: Colors.blue[900]!,
            width: 1,
          ),
          left: BorderSide(
            color: Colors.blue[900]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          ListTile(
            leading: Icon(Icons.home, color: Colors.blue),
            title: Text(
              'Home',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            selected: selectedSection == HomeSection.inicio,
            onTap: () => onSectionSelected(HomeSection.inicio),
          ),
          ListTile(
            leading: Icon(Icons.library_music_outlined, color: Colors.blue),
            title: Text(
              'Library',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            selected: selectedSection == HomeSection.biblioteca,
            onTap: () => onSectionSelected(HomeSection.biblioteca),
          ),
          ListTile(
            leading: Icon(Icons.library_books_outlined, color: Colors.blue),
            title: const Text(
              'SetLists',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            selected: selectedSection == HomeSection.setLists,
            onTap: () => onSectionSelected(HomeSection.setLists),
          ),
        ],
      ),
    );
  }
}
