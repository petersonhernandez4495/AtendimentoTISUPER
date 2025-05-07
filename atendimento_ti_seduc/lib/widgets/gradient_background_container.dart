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
      decoration: BoxDecoration( // Removido o 'const' para permitir cores dinâmicas do tema
        gradient: LinearGradient(
          // Cores atualizadas para corresponder ao gradiente da ListaChamadosScreen
          colors: [
            AppTheme.kWinBackground, // A cor cinza clara definida no seu AppTheme.dart
            Colors.white,           // Transição para branco puro
          ],
          // Opcional: adicione os 'stops' se quiser controlar a transição do gradiente
          // como fizemos na ListaChamadosScreen. Se omitido, a transição é linear.
          stops: const [0.0, 0.8], // Exemplo: Cinza no topo, transição completa para branco em 70%
                                  // Ajuste ou remova esta linha conforme sua preferência.
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child, // Exibe o conteúdo passado para o widget
    );
  }
}