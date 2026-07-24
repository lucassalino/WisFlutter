import 'package:flutter/material.dart';

/// Placeholder para tabs cujo ecrã real ainda não foi construído nesta
/// fatia do port (ver docs/reference/wis-app-overview-and-rn-prompt.md
/// para a especificação completa a implementar a seguir).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            const Text('Em breve', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
