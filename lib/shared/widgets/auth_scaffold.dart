import 'package:flutter/material.dart';

import 'glass_card.dart';
import 'spotlight_background.dart';

/// Layout partilhado pelos ecrãs de autenticação (login, registo,
/// recuperar/definir password): fundo preto com spotlight + cartão
/// central em vidro fosco. Replica `.auth-bg` + `.auth-glass`.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child, this.showBackButton = false});

  final Widget child;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SpotlightBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: GlassCard(
                    radius: 22,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 36,
                    ),
                    child: child,
                  ),
                ),
              ),
              if (showBackButton)
                Positioned(
                  top: 8,
                  left: 8,
                  child: SafeArea(
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        foregroundColor: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
