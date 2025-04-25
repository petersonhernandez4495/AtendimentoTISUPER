// lib/widgets/gradient_background_container.dart

import 'package:flutter/material.dart';
import '../config/theme/app_theme.dart'; // Importa para usar as cores do tema

class GradientBackgroundContainer extends StatelessWidget {
  final Widget child; // O conteúdo que ficará sobre o gradiente

  const GradientBackgroundContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // O Container ocupa todo o espaço disponível por padrão quando usado
      // como body de um Scaffold ou dentro de um Expanded.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          // Usa as cores definidas estaticamente na classe AppTheme
          colors: [
            AppTheme.kBackgroundGradientStart,
            AppTheme.kBackgroundGradientEnd,
          ],
          // Define a direção do gradiente (pode ser alterada aqui se necessário)
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child, // Exibe o conteúdo passado para o widget
    );
  }
}