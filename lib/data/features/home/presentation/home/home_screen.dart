import 'package:flutter/material.dart';
import 'package:music_lector/data/features/home/presentation/Library/pdf_list.dart';
import 'package:music_lector/data/features/home/presentation/SetLists/setListMenu.dart';
import 'package:music_lector/data/features/home/presentation/home/sidebar.dart';
import 'package:music_lector/data/features/home/presentation/home/topbar.dart';

enum HomeSection { inicio, biblioteca, setLists }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeSection _selectedSection = HomeSection.inicio;

  Widget _buildSection() {
    switch (_selectedSection) {
      case HomeSection.inicio:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              Text(
                '¡Bienvenido a MusicLector!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Explora, organiza y disfruta tu música favorita.',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Acción para explorar música
                },
                icon: Icon(Icons.explore),
                label: Text('Explorar música'),
              ),
            ],
          ),
        );
      case HomeSection.biblioteca:
        return Center(child: PdfList());
      case HomeSection.setLists:
        return Center(child: SetListMenu());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MusicLector - Inicio'),
        flexibleSpace: const TopBar(),
      ),
      body: Row(
        children: [
          Sidebar(
            onSectionSelected: (section) {
              setState(() {
                _selectedSection = section;
              });
            },
            selectedSection: _selectedSection,
          ),
          Expanded(child: _buildSection()),
        ],
      ),
    );
  }
}
