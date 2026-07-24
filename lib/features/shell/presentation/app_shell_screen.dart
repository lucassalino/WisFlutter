import 'package:flutter/material.dart';

import '../../../shared/widgets/coming_soon_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../songs/presentation/songs_list_screen.dart';
import 'more_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key, required this.orgId});

  final String orgId;

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardScreen(orgId: widget.orgId),
      const ComingSoonScreen(title: 'Eventos', icon: Icons.event_outlined),
      const ComingSoonScreen(title: 'Escala', icon: Icons.checklist_outlined),
      SongsListScreen(orgId: widget.orgId),
      const MoreScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            label: 'Eventos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist_outlined),
            label: 'Escala',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note_outlined),
            label: 'Repertório',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Mais'),
        ],
      ),
    );
  }
}
